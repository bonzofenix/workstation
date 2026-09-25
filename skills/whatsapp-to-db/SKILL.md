---
name: whatsapp-to-db
description: Turn a WhatsApp chat export (.zip or unzipped folder) into a queryable SQLite database — every message, every voice note transcribed locally with Whisper, text OCR'd out of images, and FTS5 full-text search across all of it. Use when the user wants to back up, archive, search or analyse a WhatsApp conversation, turn a chat or its audios/voice notes into a database, bulk-transcribe WhatsApp voice notes, or update a chat DB built earlier with a newer export.
allowed-tools:
  - Bash(python3 ~/.claude/skills/whatsapp-to-db/scripts/wa2db.py *)
  - Bash(uv run --with mlx-whisper python3 ~/.claude/skills/whatsapp-to-db/scripts/wa2db.py *)
  - Bash(uv run --with faster-whisper python3 ~/.claude/skills/whatsapp-to-db/scripts/wa2db.py *)
  - Bash(sqlite3 *)
  - Read
---

# WhatsApp export → SQLite

## Privacy

The script runs locally and never uploads chat content or media; it only downloads Python
packages and the Whisper model. Anything **you** read into this conversation (sample messages,
sender names, query results) is sent to the model, so read only what the task needs. Don't send
chat content, transcripts or media to any other service unless the user asks.

## Steps

Commands use the full script path so they match the allowed-tools patterns; write them out in
full each time. Pick a working dir outside the export, e.g. `~/wa/<chat-name>/`, and use
`--db <dir>/chat.sqlite`.

1. **Ingest** the export (a `.zip` or an unzipped folder):
   ```bash
   python3 ~/.claude/skills/whatsapp-to-db/scripts/wa2db.py ingest "<export.zip or folder>" --db <dir>/chat.sqlite
   ```
   - A 0-byte, truncated or still-growing zip is refused: the export is usually still
     transferring (AirDrop/iCloud). Wait and retry.
   - A zip is extracted to a new `<dir>/export-<stamp>/`. A folder is used in place and the DB
     stores absolute paths into it, so it must stay put (if it moves, `transcribe`/`ocr` stop and
     say so; re-ingest from the new location).
   - **Re-ingesting** (e.g. a newer export of the same chat) builds the new DB in a temp file and
     swaps it in only once complete. The previous one is kept as `chat.sqlite.<stamp>.bak`. Its
     transcripts, translations and OCR are reused by media filename, so only new voice notes need
     transcribing. Errors are not carried over, so a clip that was missing before but is present
     now gets transcribed.
   - Each zip re-ingest leaves another `export-<stamp>/` (exports with media can be several GB).
     `sqlite3 <db> "select value from meta where key='export_dir'"` names the current one; tell
     the user which are superseded so they can `trash` them.
   - `--carry-from <other.sqlite>` also reuses work from another DB, e.g. one built before this
     skill existed. Where both have a value, the existing `--db` wins. It needs `audios.file` and
     `messages.media_file`; other missing columns are fine. Opened read-only.
   - Day/month order is auto-detected. If it warns the order is ambiguous, check a few dates
     against the user's memory and pass `--date-order mdy` if needed.
   - Tell the user the printed counts (date range, messages per sender, kinds) and any warnings.
     These ones need action:
     - *media files … aren't referenced*: the attachment markers weren't recognised.
     - *look like timestamps but didn't parse*: an unknown header format.
     - *earlier transcripts have no voice note in this export*: they survive only in the `.bak`.

2. **Index** straight away so text search works while transcription runs:
   ```bash
   python3 ~/.claude/skills/whatsapp-to-db/scripts/wa2db.py index --db <dir>/chat.sqlite
   ```

3. **Transcribe voice notes**. This is the slow step. Before starting:
   - **Language**: sample some text
     (`sqlite3 <db> "select text from messages where kind='text' order by random() limit 20"`)
     and pass `--lang` (ISO 639-1: `es`, `en`, `pt`, …). Auto-detection misfires on short or
     noisy clips.
   - **Translation**: ask the user. The default is none; keeping the original language is a
     common choice. `--translate` is a *separate run* of Whisper's translate task that fills
     `translation` (English only) and doesn't touch `transcript`. For both, run once without it
     and once with it; each run takes about as long as the other. Any other target language
     would need an LLM pass over the transcripts, which sends them to the model, so ask first.
   - **Time**: `status` shows `pending`. whisper-large-v3 on Apple Silicon takes about 8–10 s
     per clip, so 2,000 clips is about 5 h. Tell the user before starting a run that long.
   - **Backend**: `mlx` (default, Apple Silicon, needs `ffmpeg`), or `--backend faster` with
     `uv run --with faster-whisper …` elsewhere. `--model mlx-community/whisper-large-v3-turbo`
     is several times faster at a small accuracy cost, but it can't translate (the script
     refuses the combination).

   Smoke-test 3 clips, then run the rest detached:
   ```bash
   uv run --with mlx-whisper python3 ~/.claude/skills/whatsapp-to-db/scripts/wa2db.py transcribe --db <dir>/chat.sqlite --lang es --limit 3
   uv run --with mlx-whisper python3 ~/.claude/skills/whatsapp-to-db/scripts/wa2db.py transcribe --db <dir>/chat.sqlite --lang es --detach
   ```
   - The first `uv run --with mlx-whisper` installs dependencies (5–10 min), and the model
     (~3 GB) downloads on first use. Both are cached afterwards.
   - **Detach long runs.** A plain `nohup … &` from a tool shell doesn't reliably survive that
     shell exiting. `--detach` forks into its own session, prints the child's pid and logs to
     `<dir>/transcribe.log`. (macOS has no `setsid` command; don't look for one.)
   - About a minute after launching, Read the log to confirm the `start` line and the first
     progress line. Later, use `status` (it says whether a run is active) or Read the log again.
   - A failing clip is logged as a `FAIL` line and the run continues; the run then exits 1. Ten
     failures in a row stop it, because that means a setup problem (ffmpeg, model name,
     `--lang`, network) rather than bad clips. Fix the cause, then re-run with `--retry-errors`.
     `--retry-empty` re-does clips that came back blank. A killed run resumes with the same
     command, because each clip is committed as it finishes.
   - While a run holds the DB, `ingest`, `ocr` and `index` refuse to start; run them after it
     finishes. `status` works any time.
   - Music files sent in the chat count as voice notes, and their "transcripts" are noise.
     Mention them; don't chase them.

4. **OCR images** (optional). Needs `tesseract` and its language data
   (`brew install tesseract tesseract-lang`):
   ```bash
   python3 ~/.claude/skills/whatsapp-to-db/scripts/wa2db.py ocr --db <dir>/chat.sqlite --lang spa+eng
   ```
   - `--lang` takes tesseract's 3-letter codes (`spa`, `eng`, `por`), not Whisper's. The script
     refuses languages that aren't installed and lists the ones that are.
   - Stickers are skipped.
   - `ocr_text` values:
     - `''`: checked, and less than `--min-chars` (12) of text found. Most photos have none.
     - `NULL`: not processed yet, or failed. `ocr_error` says why; re-run with `--retry-errors`.
   - HEIC photos fail, because tesseract can't read them.
   - DBs built before this skill may hold OCR failures as `''`. To redo those, run
     `sqlite3 <db> "update messages set ocr_text=null where kind='image' and ocr_text=''"`
     and then `ocr`.

5. **Index** again after transcribe/ocr fill things in. It is safe to repeat.

## Schema

| table | what |
|---|---|
| `messages` | One row per message: `ts, date, time, year_month, sender, kind, text, media_file, char_len, edited, transcript, translation, ocr_text, ocr_error, image_desc`. `transcript`/`translation` are copied from `audios` by `index`. `image_desc` is never written by the script; it only arrives through carry-over. |
| `audios` | One row per voice note whose file is named in the chat: `message_id, file, date, time, sender, transcript, translation, word_count, error, translation_error`. `error='not in export'` = referenced but absent. |
| `media` | One row per attachment: `message_id, file, date, time, sender, type, path`. `type` = the message's `kind`; `path` NULL = not in the export. |
| `messages_fts` | FTS5 over `messages.text` (`rowid` = `messages.id`). |
| `audios_fts` | FTS5 over `audios.transcript` (`rowid` = `audios.id`). |
| `all_fts` | FTS5 over text + transcript + translation + OCR, with `rowid` = `messages.id`. It is contentless, so select columns from `messages`. |
| `meta` | `export_dir`, `chat_file`, `ingested_at`. |

`kind` is one of `text, audio, image, sticker, video, file, call, deleted, system, omitted`.
`omitted` is Android's untyped "<Media omitted>". iOS "image omitted" and similar keep their type,
with `media_file` NULL.

## Queries

```sql
-- search everything, including what was said in voice notes and written in screenshots
select m.ts, m.sender, m.kind, coalesce(nullif(m.transcript,''), nullif(m.ocr_text,''), m.text)
from all_fts f join messages m on m.id = f.rowid
where all_fts match 'viaje' order by m.ts;

-- who writes more, by month
select year_month, sender, count(*) from messages where sender is not null group by 1, 2;

-- voice notes per sender, and how many words
select sender, count(*), sum(word_count) from audios group by 1;
```

## Parsing notes

- WhatsApp inserts invisible bidi marks (U+200E) before the timestamp and before `<attached:`,
  uses CRLF line endings, and newer exports put U+202F before AM/PM. These are stripped or
  normalised before matching; otherwise the regexes silently miss lines.
- A line that doesn't start with a timestamp is a continuation of the previous message. Line
  breaks inside a message are kept.
- Headers: iOS `[21/04/2025, 11:40:03] Name: text` and Android `21/04/2025, 11:40 - Name: text`,
  24h or 12h, with 2- or 4-digit years. The chat log is found by content, not file name, because
  Android names it in the phone's language.
- Attachments are linked by the filename written in the message, matched by shape
  (`<word: file.ext>` on iOS, `file.ext (words)` on Android). This works whatever the phone's UI
  language. Android matches in another language count only if the file exists in the export.
  `.was` files are animated stickers.
- The "omitted", "deleted", "edited", call and encryption notices are matched only in English.
  In other UI languages those messages stay `kind='text'`.
- A text export is always UTF-8. If the script refuses a file as non-UTF-8, it was re-saved by
  another app; get a fresh export.
