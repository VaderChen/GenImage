#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_NAME="${SCRIPT_DIR:t}"
PROJECT_PARENT="${SCRIPT_DIR:h}"
BACKUP_DIR="$SCRIPT_DIR/Backups"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
ARCHIVE_NAME="${PROJECT_NAME}-${TIMESTAMP}.zip"

export COPYFILE_DISABLE=1

if [[ ! -f "$SCRIPT_DIR/Package.swift" || ! -d "$SCRIPT_DIR/Sources" ]]; then
  print -u2 "錯誤：$SCRIPT_DIR 不是 GenImage 專案目錄。"
  exit 1
fi

if [[ ! -x /usr/bin/zip ]]; then
  print -u2 "錯誤：找不到 macOS zip 工具。"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

TEMP_ROOT="${TMPDIR:-/tmp}"
TEMP_DIR="$(mktemp -d "${TEMP_ROOT%/}/genimage-backup.XXXXXX")"
TEMP_ARCHIVE="$TEMP_DIR/$ARCHIVE_NAME"
trap 'rm -rf -- "$TEMP_DIR"' EXIT

print "正在備份 GenImage 程式…"

cd "$PROJECT_PARENT"
/usr/bin/zip -qry "$TEMP_ARCHIVE" "$PROJECT_NAME" \
  -x "$PROJECT_NAME/.build/*" \
  -x "$PROJECT_NAME/RuntimeSupport/Qwen2511Worker/.build/*" \
  -x "$PROJECT_NAME/.swiftpm/*" \
  -x "$PROJECT_NAME/dist/*" \
  -x "$PROJECT_NAME/Backups/*" \
  -x "$PROJECT_NAME/.git/*" \
  -x '*/._*' \
  -x '*/.DS_Store' \
  -x '*.bak'

mv -- "$TEMP_ARCHIVE" "$BACKUP_DIR/$ARCHIVE_NAME"

ARCHIVE_SIZE="$(du -h "$BACKUP_DIR/$ARCHIVE_NAME" | cut -f1)"
print "備份完成：$BACKUP_DIR/$ARCHIVE_NAME"
print "ZIP 大小：$ARCHIVE_SIZE"
