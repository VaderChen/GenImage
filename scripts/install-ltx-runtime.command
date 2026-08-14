#!/bin/zsh

set -euo pipefail

RUNTIME_ROOT="${GENIMAGE_LTX_RUNTIME_ROOT:-$HOME/Library/Application Support/GenImage/Runtime/ltx-2-mlx}"
PYTHON_VERSION="${GENIMAGE_LTX_PYTHON_VERSION:-3.13}"

if ! command -v uv >/dev/null 2>&1; then
  echo "找不到 uv，請先執行：brew install uv"
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "找不到 ffmpeg，請先執行：brew install ffmpeg"
  exit 1
fi

if [[ ! -d "$RUNTIME_ROOT/.git" ]]; then
  mkdir -p "${RUNTIME_ROOT:h}"
  git clone --depth 1 https://github.com/dgrauet/ltx-2-mlx.git "$RUNTIME_ROOT"
fi

for package in ltx-core-mlx ltx-pipelines-mlx; do
  cp "$RUNTIME_ROOT/README.md" "$RUNTIME_ROOT/packages/$package/README.md"
  sed -i '' 's#readme = "../../README.md"#readme = "README.md"#' \
    "$RUNTIME_ROOT/packages/$package/pyproject.toml"
done

uv python pin "$PYTHON_VERSION" --directory "$RUNTIME_ROOT"
uv sync --no-dev --directory "$RUNTIME_ROOT"

EXECUTABLE="$RUNTIME_ROOT/.venv/bin/ltx-2-mlx"
if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Runtime 安裝失敗：$EXECUTABLE"
  exit 1
fi

"$EXECUTABLE" --help >/dev/null
echo "LTX 影片 Runtime 已安裝：$EXECUTABLE"
