#!/usr/bin/env python3
"""Tests for wa2db.py"""
import argparse
import fcntl
import hashlib
import os
import shutil
import sqlite3
import subprocess
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wa2db
from wa2db import classify, parse

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wa2db.py")


def cli(*args):
    return subprocess.run([sys.executable, SCRIPT, *map(str, args)], capture_output=True, text=True)


def make_export(root, lines, files=(), name="_chat.txt"):
    root.mkdir(parents=True, exist_ok=True)
    (root / name).write_text("\r\n".join(lines) + "\r\n", encoding="utf-8")
    for f in files:
        (root / f).write_bytes(b"not really media")
    return root


def chat_file(tmp_path, lines):
    p = tmp_path / "_chat.txt"
    p.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return p


def rows(db, sql, *params):
    con = sqlite3.connect(db)
    try:
        return con.execute(sql, params).fetchall()
    finally:
        con.close()


IOS_CHAT = [
    "‎[21/04/2025, 11:40:03] Ana: ‎Messages and calls are end-to-end encrypted. Only people in this chat can read them.",
    "[21/04/2025, 11:41:00] Ana: hola",
    "[21/04/2025, 11:42:00] Bob: ‎<attached: 00000001-AUDIO-2025-04-21-11-42-00.opus>",
    "[21/04/2025, 11:43:00] Bob: ‎<attached: 00000002-AUDIO-2025-04-21-11-43-00.opus>",
    "[21/04/2025, 11:44:00] Ana: ‎<attached: 00000003-PHOTO-2025-04-21-11-44-00.jpg>",
]
IOS_FILES = ["00000001-AUDIO-2025-04-21-11-42-00.opus", "00000002-AUDIO-2025-04-21-11-43-00.opus",
             "00000003-PHOTO-2025-04-21-11-44-00.jpg"]


class TestParse:
    def test_ios_line(self, tmp_path):
        recs, _ = parse(chat_file(tmp_path, ["‎[21/04/2025, 11:40:03] Ana: hola"]))
        assert recs == [("2025-04-21", "11:40:03", "Ana", "hola")]

    def test_android_12h_us_dates(self, tmp_path):
        recs, _ = parse(chat_file(tmp_path, ["1/13/25, 9:05 PM - Ana: hi", "1/14/25, 12:10 AM - Bob: yo"]))
        assert recs == [("2025-01-13", "21:05:00", "Ana", "hi"), ("2025-01-14", "00:10:00", "Bob", "yo")]

    def test_continuation_lines_keep_line_breaks(self, tmp_path):
        recs, _ = parse(chat_file(tmp_path, ["[21/04/2025, 11:40:03] Ana: one", "two", "[21/04/2025, 11:41:00] Bob: x"]))
        assert classify(*recs[0])["text"] == "one\ntwo"

    def test_empty_body_keeps_sender(self, tmp_path):
        recs, _ = parse(chat_file(tmp_path, ["[21/04/2025, 11:40:03] Ana:"]))
        assert recs == [("2025-04-21", "11:40:03", "Ana", "")]

    def test_android_system_line_has_no_sender(self, tmp_path):
        recs, _ = parse(chat_file(tmp_path, ["13/01/2025, 21:05 - Messages and calls are end-to-end encrypted."]))
        assert recs[0][2] is None
        assert classify(*recs[0])["kind"] == "system"

    def test_ambiguous_dates_default_to_day_first(self, tmp_path):
        recs, _ = parse(chat_file(tmp_path, ["[01/02/2025, 10:00:00] Ana: x"]))
        assert recs[0][0] == "2025-02-01"

    def test_explicit_month_first(self, tmp_path):
        recs, _ = parse(chat_file(tmp_path, ["[01/02/2025, 10:00:00] Ana: x"]), "mdy")
        assert recs[0][0] == "2025-01-02"

    def test_lines_before_first_header_are_counted(self, tmp_path):
        _, diag = parse(chat_file(tmp_path, ["junk", "[01/02/2025, 10:00:00] Ana: x"]))
        assert diag["dropped"] == 1

    def test_non_utf8_fails_loudly(self, tmp_path):
        p = tmp_path / "_chat.txt"
        p.write_bytes("[01/02/2025, 10:00:00] José: ¿qué tal?\n".encode("cp1252"))
        with pytest.raises(SystemExit):
            parse(p)


class TestClassify:
    def c(self, text, files=()):
        return classify("2025-01-01", "10:00:00", "Ana", text, files)

    def test_ios_attachment(self):
        r = self.c("<attached: 00000007-AUDIO-2025-01-01-10-00-00.opus>")
        assert (r["kind"], r["media_file"]) == ("audio", "00000007-AUDIO-2025-01-01-10-00-00.opus")

    def test_ios_attachment_in_another_ui_language(self):
        assert self.c("<adjunto: 00000007-AUDIO-2025-01-01-10-00-00.opus>")["kind"] == "audio"

    def test_ios_attachment_with_caption(self):
        r = self.c("Informe.pdf • 3 pages <attached: 00001416-Informe.pdf>")
        assert (r["kind"], r["media_file"]) == ("file", "00001416-Informe.pdf")

    def test_android_filename_with_spaces(self):
        r = self.c("Presupuesto final.pdf (file attached)")
        assert r["media_file"] == "Presupuesto final.pdf"

    def test_android_other_language_needs_the_file_in_the_export(self):
        assert self.c("PTT-20250113-WA0001.opus (archivo adjunto)")["kind"] == "text"
        assert self.c("PTT-20250113-WA0001.opus (archivo adjunto)", {"PTT-20250113-WA0001.opus"})["kind"] == "audio"

    def test_stickers(self):
        assert self.c("<attached: 00000008-STICKER-2025-01-01-10-00-00.was>")["kind"] == "sticker"
        assert self.c("<attached: 00000009-STICKER-2025-01-01-10-00-00.webp>")["kind"] == "sticker"
        assert self.c("STK-20250113-WA0003.webp (file attached)")["kind"] == "sticker"

    def test_omitted_media(self):
        assert (self.c("image omitted")["kind"], self.c("image omitted")["media_file"]) == ("image", None)
        assert self.c("<Media omitted>")["kind"] == "omitted"

    @pytest.mark.parametrize("text", ["Voice call. 2 min", "Missed voice call. Tap to call back",
                                      "Silenced voice call. Focus mode", "Missed video call"])
    def test_calls(self, text):
        assert self.c(text)["kind"] == "call"

    @pytest.mark.parametrize("text", ["can we do a video call later?", "Video call tonight?"])
    def test_text_mentioning_calls(self, text):
        assert self.c(text)["kind"] == "text"

    def test_deleted_and_edited(self):
        assert self.c("This message was deleted")["kind"] == "deleted"
        r = self.c("hola <This message was edited>")
        assert (r["text"], r["edited"]) == ("hola", 1)

    def test_e2e_mention_in_normal_text_is_not_system(self):
        assert self.c("are these end-to-end encrypted?")["kind"] == "text"

    def test_counts_multiple_attachments(self):
        assert self.c("<attached: a-AUDIO.opus>\n<attached: b-AUDIO.opus>")["n_attachments"] == 2


class TestIngestAndIndex:
    def ingest(self, tmp_path, lines=IOS_CHAT, files=IOS_FILES, *extra):
        export = make_export(tmp_path / "export", lines, files)
        db = tmp_path / "out" / "chat.sqlite"
        r = cli("ingest", export, "--db", db, *extra)
        assert r.returncode == 0, r.stderr
        return export, db

    def test_ingest_counts(self, tmp_path):
        _, db = self.ingest(tmp_path)
        assert dict(rows(db, "select kind, count(*) from messages group by 1")) == {
            "system": 1, "text": 1, "audio": 2, "image": 1}
        assert rows(db, "select count(*) from audios where error is null") == [(2,)]

    def test_index_can_run_repeatedly(self, tmp_path):
        _, db = self.ingest(tmp_path)
        rows(db, "select 1")
        con = sqlite3.connect(db)
        con.execute("update audios set transcript = 'nos vemos en la estación' where id = 1")
        con.commit()
        con.close()
        for _ in range(2):
            r = cli("index", "--db", db)
            assert r.returncode == 0, r.stderr
        hits = rows(db, "select m.kind from all_fts f join messages m on m.id = f.rowid where all_fts match 'estación'")
        assert hits == [("audio",)]

    def test_reingest_keeps_transcripts_but_not_errors(self, tmp_path):
        # First export lacks the second voice note; the next one has it.
        export, db = self.ingest(tmp_path, IOS_CHAT, IOS_FILES[:1] + IOS_FILES[2:])
        assert rows(db, "select error from audios where id = 2") == [("not in export",)]
        con = sqlite3.connect(db)
        con.execute("update audios set transcript = 'hola hola' where id = 1")
        con.commit()
        con.close()
        (export / IOS_FILES[1]).write_bytes(b"now present")
        r = cli("ingest", export, "--db", db)
        assert r.returncode == 0, r.stderr
        assert rows(db, "select id, transcript, error from audios order by id") == [
            (1, "hola hola", None), (2, None, None)]
        assert len(list(db.parent.glob("chat.sqlite.*.bak"))) == 1

    def test_failed_ingest_leaves_db_untouched(self, tmp_path):
        _, db = self.ingest(tmp_path)
        before = hashlib.md5(db.read_bytes()).hexdigest()
        bad = make_export(tmp_path / "bad", ["not a whatsapp export"])
        r = cli("ingest", bad, "--db", db)
        assert r.returncode != 0
        assert hashlib.md5(db.read_bytes()).hexdigest() == before
        assert not list(db.parent.glob("*.bak")) and not list(db.parent.glob("*.partial"))

    def test_backups_get_unique_names(self, tmp_path):
        export, db = self.ingest(tmp_path)
        for _ in range(2):
            assert cli("ingest", export, "--db", db).returncode == 0
        assert len(list(db.parent.glob("chat.sqlite.*.bak*"))) == 2

    def test_carry_from_adds_to_existing_db(self, tmp_path):
        export, db = self.ingest(tmp_path)
        con = sqlite3.connect(db)
        con.execute("update audios set transcript = 'current' where id = 1")
        con.commit()
        con.close()
        old = tmp_path / "old.sqlite"  # older schema: no translation/error/ocr_error columns
        con = sqlite3.connect(old)
        con.executescript("create table audios(id integer primary key, file text, transcript text);"
                          "create table messages(id integer primary key, media_file text, ocr_text text);")
        con.executemany("insert into audios(file, transcript) values(?, ?)",
                        [(IOS_FILES[0], "stale"), (IOS_FILES[1], "from old db")])
        con.execute("insert into messages(media_file, ocr_text) values(?, 'SALE 50%')", (IOS_FILES[2],))
        con.commit()
        con.close()
        r = cli("ingest", export, "--db", db, "--carry-from", old)
        assert r.returncode == 0, r.stderr
        assert rows(db, "select transcript from audios order by id") == [("current",), ("from old db",)]
        assert rows(db, "select ocr_text from messages where kind = 'image'") == [("SALE 50%",)]

    def test_missing_source_is_not_mistaken_for_a_transfer(self, tmp_path):
        r = cli("ingest", tmp_path / "nope.zip", "--db", tmp_path / "chat.sqlite")
        assert r.returncode != 0 and "does not exist" in r.stderr

    def test_zip_source(self, tmp_path):
        export = make_export(tmp_path / "export", IOS_CHAT, IOS_FILES)
        z = shutil.make_archive(str(tmp_path / "WhatsApp Chat - Ana"), "zip", export)
        db = tmp_path / "out" / "chat.sqlite"
        r = cli("ingest", z, "--db", db)
        assert r.returncode == 0, r.stderr
        assert rows(db, "select count(*) from media where path is not null") == [(3,)]

    def test_lock_blocks_a_second_run(self, tmp_path):
        _, db = self.ingest(tmp_path)
        with open(f"{db}.lock", "w") as fh:
            fcntl.flock(fh, fcntl.LOCK_EX)
            fh.write("4242")
            fh.flush()
            r = cli("index", "--db", db)
            assert r.returncode != 0 and "4242" in r.stderr
            assert "RUNNING: pid 4242" in cli("status", "--db", db).stdout


def transcribe_args(db, **kw):
    base = dict(db=str(db), backend="mlx", model=None, lang="es", translate=False,
                retry_empty=False, retry_errors=False, limit=None, detach=False)
    return argparse.Namespace(**{**base, **kw})


class TestTranscribe:
    @pytest.fixture
    def db(self, tmp_path, monkeypatch):
        n = 12
        lines = [f"[21/04/2025, 11:{i:02d}:00] Bob: <attached: {i:08d}-AUDIO.opus>" for i in range(n)]
        export = make_export(tmp_path / "export", lines, [f"{i:08d}-AUDIO.opus" for i in range(n)])
        db = tmp_path / "chat.sqlite"
        assert cli("ingest", export, "--db", db).returncode == 0
        monkeypatch.setattr(wa2db, "check_backend", lambda backend: None)
        return db

    def run(self, monkeypatch, db, fn, **kw):
        monkeypatch.setattr(wa2db, "load_backend", lambda *a: fn)
        with pytest.raises(SystemExit) as e:
            wa2db.cmd_transcribe(transcribe_args(db, **kw))
        # Each in-process run leaves its lock fd open; drop it so the next run can lock.
        os.rename(f"{db}.lock", f"{db}.lock.{os.urandom(4).hex()}")
        return e.value.code

    def test_one_bad_clip_is_recorded_and_the_run_continues(self, db, monkeypatch):
        def fake(path):
            if path.endswith("00000003-AUDIO.opus"):
                raise RuntimeError("corrupt opus")
            return " hola "
        assert self.run(monkeypatch, db, fake) == 1
        assert rows(db, "select count(*) from audios where transcript = 'hola'") == [(11,)]
        assert rows(db, "select error from audios where error is not null") == [("RuntimeError: corrupt opus",)]
        assert self.run(monkeypatch, db, lambda p: "ya está", retry_errors=True) == 0
        assert rows(db, "select count(*) from audios where error is not null") == [(0,)]

    def test_repeated_failures_stop_the_run(self, db, monkeypatch):
        def broken(path):
            raise FileNotFoundError("ffmpeg")
        code = self.run(monkeypatch, db, broken)
        assert "in a row" in str(code)
        assert rows(db, "select count(*) from audios where error is not null") == [(wa2db.MAX_STREAK,)]

    def test_moved_export_dies_without_marking_anything(self, db, monkeypatch, tmp_path):
        os.rename(tmp_path / "export", tmp_path / "moved")
        code = self.run(monkeypatch, db, lambda p: "x")
        assert "not on disk" in str(code)
        assert rows(db, "select count(*) from audios where error is not null") == [(0,)]

    def test_translate_has_its_own_error_column(self, db, monkeypatch):
        def fail(path):
            raise RuntimeError("nope")
        self.run(monkeypatch, db, fail, translate=True, limit=1)
        assert rows(db, "select error, translation_error from audios where id = 1") == [(None, "RuntimeError: nope")]

    def test_turbo_cannot_translate(self, db):
        with pytest.raises(SystemExit):
            wa2db.cmd_transcribe(transcribe_args(db, translate=True, model="mlx-community/whisper-large-v3-turbo"))


@pytest.mark.skipif(not shutil.which("tesseract"), reason="tesseract not installed")
class TestOcr:
    def test_unreadable_image_is_a_failure_not_empty_text(self, tmp_path):
        export = make_export(tmp_path / "export", IOS_CHAT, IOS_FILES)
        db = tmp_path / "chat.sqlite"
        assert cli("ingest", export, "--db", db).returncode == 0
        r = cli("ocr", "--db", db)
        assert r.returncode == 1
        [(text, err)] = rows(db, "select ocr_text, ocr_error from messages where kind = 'image'")
        assert text is None and err

    def test_missing_language_data_is_refused(self, tmp_path):
        export = make_export(tmp_path / "export", IOS_CHAT, IOS_FILES)
        db = tmp_path / "chat.sqlite"
        assert cli("ingest", export, "--db", db).returncode == 0
        r = cli("ocr", "--db", db, "--lang", "zzz")
        assert r.returncode != 0 and "language data missing" in r.stderr
