#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

export COPYFILE_DISABLE=1

if [[ ! -f "$SCRIPT_DIR/Package.swift" || ! -d "$SCRIPT_DIR/Sources" ]]; then
  print -u2 "錯誤：$SCRIPT_DIR 不是 GenImage 專案目錄。"
  exit 1
fi

print "正在清除 GenImage 中間產物…"

if [[ -d "$SCRIPT_DIR/.build" ]]; then
  rm -rf -- "$SCRIPT_DIR/.build"
  print "已清除：.build"
fi

QWEN_WORKER_BUILD="$SCRIPT_DIR/RuntimeSupport/Qwen2511Worker/.build"
if [[ -d "$QWEN_WORKER_BUILD" ]]; then
  rm -rf -- "$QWEN_WORKER_BUILD"
  print "已清除：RuntimeSupport/Qwen2511Worker/.build"
fi

find "$SCRIPT_DIR" -type f \( \
  -name '._*' -o \
  -name '.DS_Store' -o \
  -name '*.bak' \
\) -delete

print "已清除：AppleDouble、.DS_Store 與 .bak"
print "清理完成。原始碼、模型設定、RuntimeSupport 與 Backups 均未變更。"
