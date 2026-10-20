#!/bin/bash
# Gathers every SAT-project file on this Mac into ~/Desktop/SAT_Project.
# It only COPIES files. Nothing is moved or deleted.
# Run it:  bash ~/Downloads/collect_sat_project_mac.sh

set -u
DEST="$HOME/Desktop/SAT_Project"
RECENT_DAYS=3            # downloads from the last N days are pulled in for review
MAX_MB=200               # bigger files are listed but not copied
TMP="$(mktemp -d)"

# Filename keywords (matched case-insensitively). "sat" must be its own word,
# so "saturday" or "satisfy" don't match.
NAME_RE='(^|[^a-z])(sat|psat|dsat)([^a-z]|$)|sparkl|test[ _-]?bank|bluebook|college[ _-]?board|^build\.py$|initialize_activity|xhr[ _-]?log'
# Text inside files (only checked in Downloads, Desktop, Documents).
CONTENT_RE='Sparkl|initialize_activity|[Tt]est [Bb]ank|College ?Board|Bluebook|SAT (Math|Reading|Writing|[Pp]ractice|[Tt]est|[Qq]uestion|[Pp]roject)'

echo "Searching your Mac. This can take a few minutes..."
mkdir -p "$DEST"

# 1) Name matches anywhere in your home folder
find "$HOME" \( -name Library -o -name .Trash -o -name node_modules -o -name .git \
     -o -name '.cache' -o -name '*.photoslibrary' -o -name '*.app' -o -path "$DEST" \) -prune \
     -o -type f -print 2>/dev/null \
  | awk -F/ -v re="$NAME_RE" 'tolower($NF) ~ re' > "$TMP/match.txt"

# 2) Content matches in the usual places
for d in "$HOME/Downloads" "$HOME/Desktop" "$HOME/Documents"; do
  [ -d "$d" ] || continue
  find "$d" -path "$DEST" -prune -o -type f -size -2048k \
    \( -iname '*.py' -o -iname '*.js' -o -iname '*.md' -o -iname '*.txt' -o -iname '*.json' \
       -o -iname '*.html' -o -iname '*.csv' -o -iname '*.tsv' -o -iname '*.tex' -o -iname '*.log' \) \
    -exec grep -lIE "$CONTENT_RE" {} + 2>/dev/null >> "$TMP/match.txt"
done
sort -u "$TMP/match.txt" -o "$TMP/match.txt"

# 3) Anything you downloaded recently that didn't match (you check these by hand)
find "$HOME/Downloads" -maxdepth 2 -type f -mtime -"$RECENT_DAYS" ! -name '.DS_Store' 2>/dev/null \
  | sort -u > "$TMP/recent.txt"
grep -vxFf "$TMP/match.txt" "$TMP/recent.txt" > "$TMP/review.txt" 2>/dev/null || true

category() {
  ext="$(echo "${1##*.}" | tr 'A-Z' 'a-z')"
  case "$ext" in
    md|txt|rtf|log)                         echo "01_chat_and_notes" ;;
    docx|doc|pdf|pptx|ppt|odt|pages|key)    echo "02_documents" ;;
    py|js|ts|sh|ipynb|html|htm|css|tex)     echo "03_code" ;;
    json|csv|tsv|xlsx|xls|xml|yaml|yml|har) echo "04_data" ;;
    png|jpg|jpeg|gif|webp|svg|heic)         echo "05_images" ;;
    zip|tar|gz|tgz)                         echo "06_archives" ;;
    *)                                      echo "07_other" ;;
  esac
}

: > "$TMP/manifest.tsv"
: > "$TMP/skipped.txt"
copy_one() {   # $1 = source file, $2 = folder inside DEST
  src="$1"; sub="$2"
  [ -f "$src" ] || return
  bytes=$(wc -c < "$src" | tr -d ' ')
  if [ "$bytes" -gt $((MAX_MB*1024*1024)) ]; then echo "$src" >> "$TMP/skipped.txt"; return; fi
  mkdir -p "$DEST/$sub"
  base="$(basename "$src")"; target="$DEST/$sub/$base"; n=2
  while [ -e "$target" ]; do
    cmp -s "$src" "$target" && return          # exact duplicate, skip
    target="$DEST/$sub/${base%.*}_$n.${base##*.}"; [ "$base" = "${base%.*}" ] && target="$DEST/$sub/${base}_$n"
    n=$((n+1))
  done
  cp -p "$src" "$target"
  printf '%s\t%s\t%s\t%s\n' "$sub/$(basename "$target")" "$(date -r "$src" '+%Y-%m-%d %H:%M')" "$bytes" "$src" >> "$TMP/manifest.tsv"
  case "$target" in *.zip|*.ZIP)
    mkdir -p "${target%.*}_unzipped" && unzip -qo "$target" -d "${target%.*}_unzipped" 2>/dev/null ;;
  esac
}

while IFS= read -r f; do copy_one "$f" "$(category "$f")"; done < "$TMP/match.txt"
while IFS= read -r f; do copy_one "$f" "00_REVIEW_recent_downloads"; done < "$TMP/review.txt"

# Files for the new Claude account
[ -f "$DEST/CHAT_TRANSCRIPT.md" ] || cat > "$DEST/CHAT_TRANSCRIPT.md" <<'T'
# Chat transcript from the old account

Paste the ENTIRE old SAT Project chat below this line, then save.

---
T

cat > "$DEST/CLAUDE_START_HERE.md" <<'T'
# Claude: start here

This folder holds an SAT Project that began in another Claude account. That
account ran out of usage, so the work continues here.

## Read in this order
1. `CHAT_TRANSCRIPT.md`: the full old conversation (the source of truth).
2. `README_FILE_INDEX.md`: every file in this folder and where it came from.
3. The files themselves, in the numbered folders.

## Where the work stopped
The last request in the old chat was:
1. Render the test bank docs: run `build.py` (it was at `/home/claude/tb/build.py`)
   and write the output to `out/`. Look for `build.py` in `03_code/`.
2. Retry the Sparkl "anonymous-copy" investigation in a browser tab
   (dispatch `initialize_activity` with the XHR logger). This needs Claude in Chrome
   signed in to this account. The old tab ID (939864817) no longer exists.
3. Upload everything to the claude.ai Project.

## What to do
- Read the transcript and confirm the plan with the user before running anything.
- Rebuild any missing source files from the transcript.
- Files in `00_REVIEW_recent_downloads/` matched no SAT keyword. The user should
  check them before you rely on them.
T

{
  echo "# SAT Project: file index"
  echo
  echo "Made $(date '+%Y-%m-%d %H:%M') by collect_sat_project_mac.sh. All files are copies; the originals were not touched."
  echo
  echo "| Folder | What's in it |"
  echo "|---|---|"
  echo "| \`00_REVIEW_recent_downloads\` | Recent downloads that matched no SAT keyword. Check these and delete any that aren't part of the project. |"
  echo "| \`01_chat_and_notes\` | Text, Markdown and notes |"
  echo "| \`02_documents\` | Word, PDF and slides |"
  echo "| \`03_code\` | Scripts, including build.py |"
  echo "| \`04_data\` | JSON, CSV, spreadsheets and logs |"
  echo "| \`05_images\` | Screenshots and pictures |"
  echo "| \`06_archives\` | Zip files, each with an \`_unzipped\` folder next to it |"
  echo "| \`07_other\` | Everything else |"
  echo
  echo "## Every file"
  echo
  echo "| File | Modified | Size (KB) | Original location |"
  echo "|---|---|---|---|"
  sort "$TMP/manifest.tsv" | while IFS="$(printf '\t')" read -r p d b o; do
    echo "| \`$p\` | $d | $(( (b+1023)/1024 )) | \`$o\` |"
  done
  if [ -s "$TMP/skipped.txt" ]; then
    echo; echo "## Too big to copy (over ${MAX_MB} MB), left where they are"; echo
    while IFS= read -r s; do echo "- \`$s\`"; done < "$TMP/skipped.txt"
  fi
} > "$DEST/README_FILE_INDEX.md"

count=$(wc -l < "$TMP/manifest.tsv" | tr -d ' ')
rm -rf "$TMP"
echo
echo "Done. Copied $count files into: $DEST"
echo "Next: open CHAT_TRANSCRIPT.md in that folder and paste the old chat into it."
open "$DEST" 2>/dev/null || true
