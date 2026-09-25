#!/usr/bin/env python3
"""WhatsApp chat export -> SQLite, with local voice-note transcription and image OCR.

Subcommands, in order:
  ingest      parse an export (.zip or folder) into a new DB, reusing transcripts/OCR from the old one
  transcribe  transcribe voice notes locally (mlx-whisper or faster-whisper)
  ocr         OCR images with tesseract
  index       copy transcripts onto messages and rebuild the FTS5 indexes
  status      progress counts, and whether a run is active

Every command can be re-run. ingest builds the new DB in a temp file and swaps it in only when it
is complete; transcribe and ocr commit per item and skip what is done; failures are recorded per
item and retried with --retry-errors. A lock file stops two runs touching the same DB at once.
"""
import argparse, fcntl, faulthandler, importlib.util, os, re, shutil, signal, sqlite3, subprocess, sys, tempfile, time, warnings, zipfile
from pathlib import Path

AUDIO = {"opus", "m4a", "mp3", "wav", "ogg", "aac", "amr"}
IMAGE = {"jpg", "jpeg", "png", "webp", "gif", "heic"}
VIDEO = {"mp4", "mov", "3gp", "mkv"}

# Zero-width and bidi marks (WhatsApp puts U+200E before the timestamp and before "<attached:"),
# and the non-breaking spaces newer exports put before AM/PM.
INVISIBLE = dict.fromkeys(map(ord, "​‎‏‪‫‬‭‮⁠﻿"), None)
SPACES = {0x202F: " ", 0x00A0: " "}

TS = r"(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4}),? (\d{1,2}):(\d{2})(?::(\d{2}))?(?: ?([AaPp])\.? ?[Mm]\.?)?"
IOS = re.compile(r"^\[" + TS + r"\] (.*)$")          # [21/04/2025, 11:40:03] Name: text
ANDROID = re.compile(r"^" + TS + r" - (.*)$")         # 21/04/2025, 11:40 - Name: text
NEAR_HEADER = re.compile(r"^\[?\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}")
SENDER = re.compile(r"^([^:\n]+?):(?: (.*)|$)", re.S)  # "Name: text", or "Name:" with an empty body

# Attachment markers are worded in the phone's UI language ("<attached: X>", "<adjunto: X>",
# "X (file attached)", "X (archivo adjunto)"), so match their shape instead of the words.
IOS_ATTACHED = re.compile(r"<[^<>:\n]+: ([^<>\n]+\.\w+)>")
ANDROID_ATTACHED = re.compile(r"^(.+\.\w+) \(([^()\n]+)\)$", re.M)
STICKER = re.compile(r"(-STICKER-|^STK-)|\.was$", re.I)   # .was = animated sticker

# These are English-only; other UI languages leave such messages as kind 'text'.
OMITTED = re.compile(r"^<?(image|audio|video|sticker|document|gif|media) omitted>?$", re.I)
CALL = re.compile(r"^(missed |silenced )?(group )?(voice|video) call(\.|$)", re.I)
DELETED = re.compile(r"^(this message was deleted|you deleted this message)\.?$", re.I)
EDITED = "<This message was edited>"
E2E = "Messages and calls are end-to-end encrypted"

MAX_STREAK = 10  # this many failures in a row means the setup is broken, not the clips

SCHEMA = """
CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE messages(
  id INTEGER PRIMARY KEY, ts TEXT, date TEXT, time TEXT, year_month TEXT,
  sender TEXT, kind TEXT, text TEXT, media_file TEXT, char_len INT, edited INT DEFAULT 0,
  transcript TEXT, translation TEXT, ocr_text TEXT, ocr_error TEXT, image_desc TEXT);
CREATE TABLE audios(
  id INTEGER PRIMARY KEY, message_id INT, file TEXT, date TEXT, time TEXT, sender TEXT,
  transcript TEXT, translation TEXT, word_count INT, error TEXT, translation_error TEXT);
CREATE TABLE media(
  id INTEGER PRIMARY KEY, message_id INT, file TEXT, date TEXT, time TEXT, sender TEXT,
  type TEXT, path TEXT);
CREATE INDEX i_m_date ON messages(date);
CREATE INDEX i_m_send ON messages(sender);
CREATE INDEX i_m_kind ON messages(kind);
CREATE INDEX i_a_date ON audios(date);
CREATE VIRTUAL TABLE messages_fts USING fts5(text, content='messages', content_rowid='id');
CREATE VIRTUAL TABLE audios_fts USING fts5(transcript, content='audios', content_rowid='id');
CREATE VIRTUAL TABLE all_fts USING fts5(body, content='');
"""


def log(*a):
    print(*a, flush=True)


def stamp():
    return time.strftime("%F %T")


def die(msg):
    sys.exit(f"error: {msg}")


def connect(db):
    return sqlite3.connect(db, timeout=60)


def unique(path):
    """`path`, or `path-2`, `path-3`, ... whichever doesn't exist yet."""
    cand, n = path, 1
    while os.path.exists(cand):
        n += 1
        cand = f"{path}-{n}"
    return cand


# ---------- locking ----------

def lock(db):
    """Take <db>.lock for the life of this process (and of a detached child), or die."""
    fd = os.open(db + ".lock", os.O_RDWR | os.O_CREAT, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        pid = os.pread(fd, 20, 0).decode(errors="replace").strip() or "?"
        die(f"another wa2db run (pid {pid}) is using {db}; wait for it to finish or stop it first")
    mark_lock(fd)
    return fd


def mark_lock(fd):
    os.ftruncate(fd, 0)
    os.pwrite(fd, str(os.getpid()).encode(), 0)


def running(db):
    """pid of the run holding <db>.lock, or None."""
    if not os.path.exists(db + ".lock"):
        return None
    fd = os.open(db + ".lock", os.O_RDONLY)
    try:
        fcntl.flock(fd, fcntl.LOCK_SH | fcntl.LOCK_NB)
        return None
    except BlockingIOError:
        return os.pread(fd, 20, 0).decode(errors="replace").strip() or "?"
    finally:
        os.close(fd)


# ---------- parsing ----------

def unpack(src, work):
    """Return the export directory, unzipping `src` into a new work/export-<stamp> if it is a zip."""
    if not os.path.exists(src):
        die(f"{src} does not exist")
    if os.path.isdir(src):
        return os.path.realpath(src)
    if not zipfile.is_zipfile(src):
        die(f"{src} is not a readable zip ({os.path.getsize(src)} bytes). A 0-byte or truncated zip "
            "usually means the WhatsApp export is still transferring; wait and retry.")
    s1 = os.path.getsize(src); time.sleep(2); s2 = os.path.getsize(src)
    if s1 != s2:
        die(f"{src} is still growing ({s1} -> {s2} bytes); wait for the transfer to finish")
    with zipfile.ZipFile(src) as z:
        bad = z.testzip()
        if bad:
            die(f"corrupt member in zip: {bad}")
        # A fresh directory each time: the current DB's media paths keep pointing at the old one.
        dest = unique(os.path.join(work, "export-" + time.strftime("%Y%m%d-%H%M%S")))
        z.extractall(dest)
    return os.path.realpath(dest)


def find_chat_txt(export_dir):
    """The chat log's file name depends on the platform and UI language, so pick the .txt that parses."""
    cands = []
    for root, _, files in os.walk(export_dir):
        for f in files:
            if f.lower().endswith(".txt"):
                p = os.path.join(root, f)
                with open(p, encoding="utf-8-sig", errors="replace") as fh:
                    head = [fh.readline().translate(INVISIBLE).translate(SPACES) for _ in range(5)]
                if any(IOS.match(l) or ANDROID.match(l) for l in head):
                    cands.append(p)
    if len(cands) > 1:
        named = [p for p in cands if os.path.basename(p) == "_chat.txt" or "whatsapp" in os.path.basename(p).lower()]
        cands = named if len(named) == 1 else cands
    if len(cands) != 1:
        die(f"expected one WhatsApp chat log (.txt) in {export_dir}, found: {cands or 'none'}")
    return cands[0]


def parse(path, date_order="auto"):
    """Return ([(date, time, sender, body)], diagnostics). A line that doesn't start with a
    timestamp header continues the previous message."""
    try:
        with open(path, encoding="utf-8-sig") as fh:  # strict: mojibake must fail loudly
            lines = fh.read().split("\n")
    except UnicodeDecodeError as e:
        die(f"{path} is not UTF-8 ({e}); WhatsApp writes UTF-8 — was it re-saved by another app?")
    recs, heads, dropped, near = [], [], 0, 0
    for line in lines:
        line = line.rstrip("\r").translate(INVISIBLE).translate(SPACES)
        m = IOS.match(line) or ANDROID.match(line)
        if m:
            recs.append([m.groups()[:7], m.group(8)])
            heads.append((int(m.group(1)), int(m.group(2))))
        elif recs:
            recs[-1][1] += "\n" + line
            near += bool(NEAR_HEADER.match(line))
        elif line.strip():
            dropped += 1
    if not recs:
        die(f"no message headers recognised in {path}; unknown export format")

    if date_order == "auto":
        if any(a > 12 for a, _ in heads):
            date_order = "dmy"
        elif any(b > 12 for _, b in heads):
            date_order = "mdy"
        else:
            date_order = "dmy"
            log("warning: day/month order is ambiguous; assuming dd/mm. Pass --date-order mdy if wrong.")

    out = []
    for (a, b, y, hh, mm, ss, ampm), body in recs:
        d, mo = (a, b) if date_order == "dmy" else (b, a)
        y = int(y) + (2000 if len(y) == 2 else 0)
        h = int(hh)
        if ampm:
            h = h % 12 + (12 if ampm.lower() == "p" else 0)
        body = body.rstrip("\n")  # the file's final newline, or blank lines before the next header
        m = SENDER.match(body)
        sender, text = (m.group(1).strip(), m.group(2) or "") if m else (None, body)  # Android system lines have no "Name:"
        out.append((f"{y:04d}-{int(mo):02d}-{int(d):02d}", f"{h:02d}:{mm}:{ss or '00'}", sender, text))
    return out, {"dropped": dropped, "near_headers": near}


def classify(date, time_, sender, text, files=()):
    """Message row for one parsed message. `files` = names present in the export, used to confirm
    Android attachments whose marker isn't in English."""
    edited = EDITED in text
    text = "\n".join(" ".join(l.split()) for l in text.replace(EDITED, "").split("\n")).strip()
    found = [m.group(1).strip() for m in IOS_ATTACHED.finditer(text)]
    found += [m.group(1).strip() for m in ANDROID_ATTACHED.finditer(text)
              if m.group(2).lower() == "file attached" or m.group(1).strip() in files]
    media = found[0] if found else None
    kind = "text"
    if media:
        ext = media.rsplit(".", 1)[-1].lower()
        kind = ("sticker" if STICKER.search(media) else "audio" if ext in AUDIO else
                "image" if ext in IMAGE else "video" if ext in VIDEO else "file")
    elif OMITTED.match(text):
        w = OMITTED.match(text).group(1).lower()
        kind = {"image": "image", "gif": "image", "sticker": "sticker", "audio": "audio",
                "video": "video", "document": "file"}.get(w, "omitted")  # Android: untyped "<Media omitted>"
    elif sender is None or text.startswith(E2E):
        kind = "system"
    elif DELETED.match(text):
        kind = "deleted"
    elif CALL.match(text):
        kind = "call"
    return dict(ts=f"{date}T{time_}", date=date, time=time_, year_month=date[:7], sender=sender,
                kind=kind, text=text, media_file=media, char_len=len(text), edited=int(edited),
                n_attachments=len(found))


# ---------- ingest ----------

def carried(path):
    """({file: (transcript, translation)}, {file: (ocr_text, image_desc)}) from an earlier DB.
    Errors are not carried: they describe the old export (e.g. a missing file), not the new one."""
    old = sqlite3.connect(Path(path).resolve().as_uri() + "?mode=ro", uri=True)
    cols = lambda t: {r[1] for r in old.execute(f"pragma table_info({t})")}
    ac, mc = cols("audios"), cols("messages")
    if "file" not in ac or "media_file" not in mc:
        die(f"can't reuse {path}: it has no audios.file / messages.media_file columns")
    pick = lambda have, c: c if c in have else "null"
    audio = {f: (t, tr) for f, t, tr in old.execute(
        f"select file, {pick(ac, 'transcript')}, {pick(ac, 'translation')} from audios where file is not null")}
    media = {f: (o, d) for f, o, d in old.execute(
        f"select media_file, {pick(mc, 'ocr_text')}, {pick(mc, 'image_desc')} from messages "
        f"where media_file is not null")}
    old.close()
    return audio, media


def merge(into, new):
    """Fill gaps in `into` from `new`, field by field; values already in `into` win."""
    for k, v in new.items():
        cur = into.get(k)
        into[k] = v if cur is None else tuple(c if c is not None else n for c, n in zip(cur, v))


def build(tmp, export_dir, chat, records, files, keep_a, keep_m):
    con = sqlite3.connect(tmp)
    con.executescript(SCHEMA)
    con.executemany("insert into meta values(?,?)",
                    [("export_dir", export_dir), ("chat_file", chat), ("ingested_at", stamp())])
    stats = dict(transcripts=0, ocr=0, multi=0, linked=set())
    for date, time_, sender, body in records:
        r = classify(date, time_, sender, body, files)
        f = r["media_file"]
        ocr, desc = keep_m.get(f, (None, None)) if f else (None, None)
        mid = con.execute(
            "insert into messages(ts,date,time,year_month,sender,kind,text,media_file,char_len,edited,ocr_text,image_desc)"
            " values(:ts,:date,:time,:year_month,:sender,:kind,:text,:media_file,:char_len,:edited,:ocr,:desc)",
            {**r, "ocr": ocr, "desc": desc}).lastrowid
        stats["ocr"] += ocr is not None
        stats["multi"] += r["n_attachments"] > 1
        if not f:
            continue
        stats["linked"].add(f)
        path = files.get(f)
        con.execute("insert into media(message_id,file,date,time,sender,type,path) values(?,?,?,?,?,?,?)",
                    (mid, f, date, time_, sender, r["kind"], path))
        if r["kind"] == "audio":
            t, tr = keep_a.get(f, (None, None))
            stats["transcripts"] += t is not None
            con.execute("insert into audios(message_id,file,date,time,sender,transcript,translation,word_count,error)"
                        " values(?,?,?,?,?,?,?,?,?)",
                        (mid, f, date, time_, sender, t, tr, len(t.split()) if t else None,
                         None if path else "not in export"))
    con.commit()
    con.close()
    return stats


def cmd_ingest(a):
    db = os.path.abspath(a.db)
    os.makedirs(os.path.dirname(db), exist_ok=True)
    lock(db)
    keep_a, keep_m = {}, {}
    for src in [p for p in (db if os.path.exists(db) else None, a.carry_from) if p]:  # current DB wins
        au, me = carried(src)
        log(f"reusing from {src}: {sum(t is not None for t, _ in au.values())} transcripts, "
            f"{sum(o is not None for o, _ in me.values())} OCR results")
        merge(keep_a, au)
        merge(keep_m, me)

    export_dir = unpack(a.source, os.path.dirname(db))
    chat = find_chat_txt(export_dir)
    records, diag = parse(chat, a.date_order)  # parse everything before writing anything
    files = {}
    for root, _, fs in os.walk(export_dir):
        for f in fs:
            files.setdefault(f, os.path.join(root, f))

    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(db), prefix=os.path.basename(db) + ".", suffix=".partial")
    os.close(fd)
    try:
        st = build(tmp, export_dir, chat, records, files, keep_a, keep_m)
    except BaseException:
        os.remove(tmp)  # only ever the half-built file this run created
        raise
    bak = None
    if os.path.exists(db):
        bak = unique(f"{db}.{time.strftime('%Y%m%d-%H%M%S')}.bak")
        try:
            os.link(db, bak)
        except OSError:
            shutil.copy2(db, bak)
        log(f"previous DB kept as {bak}")
    os.replace(tmp, db)  # atomic: the DB is either the old one or the complete new one

    if keep_a or keep_m:
        log(f"reused {st['transcripts']} transcripts and {st['ocr']} OCR results")
    lost = [f for f, (t, _) in keep_a.items() if t is not None and f not in st["linked"]]
    if lost:
        log(f"warning: {len(lost)} earlier transcripts have no voice note in this export (e.g. {lost[0]}); "
            f"they are not in the new DB, only in {bak or a.carry_from}")
    if diag["dropped"]:
        log(f"warning: ignored {diag['dropped']} lines before the first message")
    if diag["near_headers"]:
        log(f"warning: {diag['near_headers']} lines look like timestamps but didn't parse as message headers; "
            "they were appended to the previous message (unrecognised header variant?)")
    if st["multi"]:
        log(f"warning: {st['multi']} messages reference more than one attachment; only the first is linked")
    orphans = [f for f in files if f.rsplit(".", 1)[-1].lower() in AUDIO | IMAGE | VIDEO and f not in st["linked"]]
    if orphans:
        log(f"warning: {len(orphans)} media files in the export aren't referenced by any message (e.g. {orphans[0]}). "
            "If that's most of them, the attachment markers weren't recognised.")
    con = connect(db)
    missing = con.execute("select count(*) from media where path is null").fetchone()[0]
    if missing:
        log(f"note: {missing} attachments are referenced in the chat but absent from the export")
    status(con)


# ---------- transcribe ----------

def check_backend(backend):
    mod, pkg = ("mlx_whisper", "mlx-whisper") if backend == "mlx" else ("faster_whisper", "faster-whisper")
    if not importlib.util.find_spec(mod):
        die(f"{pkg} is not installed; run via: uv run --with {pkg} python3 {sys.argv[0]} transcribe ...")
    if backend == "mlx" and not shutil.which("ffmpeg"):
        die("mlx-whisper decodes audio with ffmpeg, which is not on PATH (brew install ffmpeg)")


def load_backend(name, model, lang, task):
    if name == "mlx":
        # mlx's multiprocessing helper warns at exit in a detached run; harmless, and it reads like a crash.
        warnings.filterwarnings("ignore", message="resource_tracker")
        import mlx_whisper
        model = model or "mlx-community/whisper-large-v3-mlx"
        return lambda p: mlx_whisper.transcribe(p, path_or_hf_repo=model, language=lang,
                                                task=task, fp16=True)["text"]
    from faster_whisper import WhisperModel
    m = WhisperModel(model or "large-v3", compute_type="auto")
    return lambda p: "".join(s.text for s in m.transcribe(p, language=lang, task=task)[0])


def detach(logfile, lockfd):
    """Fork into a new session so the run survives the launching shell exiting. The child keeps
    the lock; the log is opened first so a bad path fails here, not silently in the child."""
    out = os.open(logfile, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
    pid = os.fork()
    if pid:
        log(f"detached as pid {pid}; progress in {logfile}")
        os._exit(0)
    os.setsid()
    null = os.open(os.devnull, os.O_RDONLY)
    os.dup2(null, 0); os.dup2(out, 1); os.dup2(out, 2)
    mark_lock(lockfd)
    faulthandler.enable()  # native crashes (e.g. in MLX) still leave a traceback in the log


def work_loop(con, todo, attempt, save, record_error, what):
    """Run `attempt(path)` per item, saving results and recording failures. Returns #failed."""
    def on_term(*_):
        log(f"{stamp()} stopped by SIGTERM; finished items are saved, rerun the same command to resume")
        sys.exit(143)
    signal.signal(signal.SIGTERM, on_term)
    t0, failed, streak = time.time(), 0, 0
    for i, (item_id, name, path) in enumerate(todo, 1):
        try:
            result = attempt(path)
        except Exception as e:  # one bad file mustn't end a multi-hour run; it's retried with --retry-errors
            err = f"{type(e).__name__}: {e}"[:500]
            record_error(item_id, err)
            con.commit()
            failed += 1
            streak += 1
            log(f"{stamp()} FAIL {name}: {err}")
            if streak >= MAX_STREAK:
                die(f"{streak} {what} failed in a row, so the setup is broken rather than the files "
                    f"(last: {err}). Fix it, then rerun with --retry-errors.")
            continue
        streak = 0
        save(item_id, result)
        con.commit()  # per item: a killed run loses at most the item in progress
        if i % 10 == 0 or i == len(todo):
            el = time.time() - t0
            log(f"{stamp()} {i}/{len(todo)}  {el/60:.1f}min  {el/i:.1f}s/item  eta={el/i*(len(todo)-i)/60:.0f}min")
    return failed


def missing_on_disk(todo):
    gone = [p for _, _, p in todo if not os.path.exists(p)]
    if gone:
        die(f"{len(gone)} of {len(todo)} files are not on disk (e.g. {gone[0]}). Was the export folder "
            "moved or deleted? Re-ingest from where it is now. Nothing was marked.")


def cmd_transcribe(a):
    db = os.path.abspath(a.db)
    if a.translate and a.model and "turbo" in a.model:
        die("turbo models weren't trained to translate; they return the original language. Use large-v3.")
    check_backend(a.backend)
    lockfd = lock(db)
    con = connect(db)
    col, errcol = ("translation", "translation_error") if a.translate else ("transcript", "error")
    cond = f"a.{col} is null and a.{errcol} is null"
    if a.retry_empty:
        cond += f" or a.{col} = ''"
    if a.retry_errors:
        cond += f" or a.{errcol} is not null"
    todo = con.execute(f"select a.id, a.file, m.path from audios a join media m on m.message_id = a.message_id"
                       f" where m.path is not null and ({cond}) order by a.id").fetchall()
    todo = todo[:a.limit] if a.limit else todo
    missing_on_disk(todo)
    verb = "translate" if a.translate else "transcribe"
    log(f"{len(todo)} voice notes to {verb}")
    if not todo:
        return
    if a.detach:
        con.close()
        detach(os.path.join(os.path.dirname(db), "transcribe.log"), lockfd)
        con = connect(db)
    log(f"{stamp()} start pid={os.getpid()} {verb} todo={len(todo)} backend={a.backend} "
        f"model={a.model or 'default'} lang={a.lang or 'auto'}")
    run = load_backend(a.backend, a.model, a.lang, verb)

    def save(aid, txt):
        txt = txt.strip()
        if a.translate:
            con.execute("update audios set translation=?, translation_error=null where id=?", (txt, aid))
        else:
            con.execute("update audios set transcript=?, word_count=?, error=null where id=?",
                        (txt, len(txt.split()), aid))

    failed = work_loop(con, todo, run, save,
                       lambda aid, err: con.execute(f"update audios set {errcol}=? where id=?", (err, aid)),
                       "voice notes")
    log(f"{stamp()} finished: {len(todo) - failed} ok, {failed} failed"
        + ("; rerun with --retry-errors after checking the FAIL lines" if failed else "") + ". Run `index` next.")
    sys.exit(1 if failed else 0)


# ---------- ocr ----------

def cmd_ocr(a):
    db = os.path.abspath(a.db)
    if not shutil.which("tesseract"):
        die("tesseract not found (brew install tesseract tesseract-lang)")
    have = set(subprocess.run(["tesseract", "--list-langs"], capture_output=True, text=True).stdout.split("\n")[1:])
    absent = [l for l in a.lang.split("+") if l not in have]
    if absent:
        die(f"tesseract language data missing for {absent} (brew install tesseract-lang). Codes are "
            f"3-letter (spa, eng, por), not Whisper's 2-letter ones. Installed: {', '.join(sorted(have - {''}))}")
    lock(db)
    con = connect(db)
    cond = "m.ocr_text is null and m.ocr_error is null" + (" or m.ocr_error is not null" if a.retry_errors else "")
    todo = con.execute("select m.id, m.media_file, md.path from messages m join media md on md.message_id = m.id"
                       f" where m.kind = 'image' and md.path is not null and ({cond}) order by m.id").fetchall()
    missing_on_disk(todo)
    log(f"{len(todo)} images to OCR")

    def attempt(path):
        # realpath: this tesseract can't open /tmp/... but can open the same file as /private/tmp/...
        r = subprocess.run(["tesseract", os.path.realpath(path), "-", "-l", a.lang, "--psm", "3"],
                           capture_output=True, text=True, timeout=120)
        if r.returncode:
            raise RuntimeError((r.stderr.strip().splitlines() or [f"exit {r.returncode}"])[-1])
        return " ".join(r.stdout.split())

    def save(mid, txt):
        # Most photos have no text and tesseract emits short garbage for them; '' = checked, no text.
        con.execute("update messages set ocr_text=?, ocr_error=null where id=?",
                    (txt if len(txt) >= a.min_chars else "", mid))

    failed = work_loop(con, todo, attempt, save,
                       lambda mid, err: con.execute("update messages set ocr_error=? where id=?", (err, mid)),
                       "images")
    log(f"{stamp()} finished: {len(todo) - failed} ok, {failed} failed"
        + ("; rerun with --retry-errors after checking the FAIL lines" if failed else "") + ". Run `index` next.")
    sys.exit(1 if failed else 0)


# ---------- index / status ----------

def cmd_index(a):
    db = os.path.abspath(a.db)
    lock(db)
    con = connect(db)
    con.execute("update messages set transcript = (select transcript from audios where message_id = messages.id),"
                " translation = (select translation from audios where message_id = messages.id)"
                " where kind = 'audio'")
    con.execute("insert into messages_fts(messages_fts) values('rebuild')")
    con.execute("insert into audios_fts(audios_fts) values('rebuild')")
    con.execute("insert into all_fts(all_fts) values('delete-all')")  # contentless: plain DELETE is refused
    con.execute("insert into all_fts(rowid, body) select id, trim(coalesce(text,'')||' '||coalesce(transcript,'')"
                "||' '||coalesce(translation,'')||' '||coalesce(ocr_text,'')) from messages")
    con.commit()
    status(con)


def status(con):
    q = lambda sql: con.execute(sql).fetchone()[0]
    has_file = "from audios a join media m on m.message_id = a.message_id where m.path is not null"
    log(f"messages {q('select count(*) from messages')}  "
        f"({q('select min(date) from messages')} -> {q('select max(date) from messages')})")
    for k, n in con.execute("select kind, count(*) from messages group by 1 order by 2 desc"):
        log(f"  {k:8} {n}")
    for s, n in con.execute("select sender, count(*) from messages where sender is not null group by 1 order by 2 desc"):
        log(f"  sender {s}: {n}")
    log("voice notes {}: transcribed {}, blank {}, pending {}, failed {}, not in export {}, translated {}".format(
        q("select count(*) from audios"),
        q("select count(*) from audios where transcript != ''"),
        q("select count(*) from audios where transcript = ''"),
        q(f"select count(*) {has_file} and a.transcript is null and a.error is null"),
        q(f"select count(*) {has_file} and a.error is not null"),
        q("select count(*) from audios where error = 'not in export'"),
        q("select count(*) from audios where translation is not null")))
    img = "from messages m join media md on md.message_id = m.id where m.kind = 'image'"
    log("images {}: with text {}, no text {}, pending {}, failed {}".format(
        q("select count(*) from messages where kind = 'image'"),
        q(f"select count(*) {img} and m.ocr_text != ''"),
        q(f"select count(*) {img} and m.ocr_text = ''"),
        q(f"select count(*) {img} and md.path is not null and m.ocr_text is null and m.ocr_error is null"),
        q(f"select count(*) {img} and m.ocr_error is not null")))
    for err, n in con.execute("select substr(e, 1, 100), count(*) from (select error e from audios where error != 'not in export'"
                              " union all select translation_error from audios union all select ocr_error from messages)"
                              " where e is not null group by 1 order by 2 desc limit 5"):
        log(f"  failure x{n}: {err}")


def cmd_status(a):
    db = os.path.abspath(a.db)
    pid = running(db)
    log(f"RUNNING: pid {pid} holds {db}.lock" if pid else "no run in progress")
    status(connect(db))


def main():
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # `status | head` should just stop
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("ingest", help="parse an export into a new DB")
    s.add_argument("source", help="export .zip or unzipped folder (a folder must stay where it is: the DB stores paths into it)")
    s.add_argument("--date-order", choices=["auto", "dmy", "mdy"], default="auto",
                   help="day/month order of the timestamps (default: detect)")
    s.add_argument("--carry-from", help="another DB to reuse transcripts/OCR from, in addition to --db if it exists")
    s = sub.add_parser("transcribe", help="transcribe voice notes locally")
    s.add_argument("--backend", choices=["mlx", "faster"], default="mlx",
                   help="mlx = mlx-whisper (Apple Silicon); faster = faster-whisper (Linux/Intel/CUDA)")
    s.add_argument("--model", help="default: whisper-large-v3 for the chosen backend")
    s.add_argument("--lang", help="ISO 639-1 code, e.g. es. Recommended: auto-detect misfires on short clips")
    s.add_argument("--translate", action="store_true",
                   help="separate pass: Whisper's translate task (English only) into `translation`; doesn't fill `transcript`")
    s.add_argument("--retry-empty", action="store_true", help="also redo clips whose result was blank")
    s.add_argument("--retry-errors", action="store_true", help="also redo clips that failed before")
    s.add_argument("--limit", type=int, help="process at most N clips (smoke test)")
    s.add_argument("--detach", action="store_true",
                   help="run in the background in its own session, logging to <db dir>/transcribe.log")
    s = sub.add_parser("ocr", help="OCR images with tesseract")
    s.add_argument("--lang", default="eng", help="tesseract languages, 3-letter codes joined by +, e.g. spa+eng")
    s.add_argument("--min-chars", type=int, default=12, help="shorter OCR output is stored as '' (no text)")
    s.add_argument("--retry-errors", action="store_true", help="also redo images that failed before")
    sub.add_parser("index", help="copy transcripts onto messages and rebuild full-text search")
    sub.add_parser("status", help="progress counts, and whether a run is active")
    for sp in sub.choices.values():
        sp.add_argument("--db", required=True, help="path to the SQLite file")
    a = p.parse_args()
    if a.cmd != "ingest" and not os.path.exists(a.db):
        die(f"{a.db} does not exist; run ingest first")
    {"ingest": cmd_ingest, "transcribe": cmd_transcribe, "ocr": cmd_ocr, "index": cmd_index,
     "status": cmd_status}[a.cmd](a)


if __name__ == "__main__":
    main()
