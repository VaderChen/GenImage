#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

export COPYFILE_DISABLE=1

ensure_metal_toolchain() {
  local metal_path=""
  local metallib_path=""

  metal_path="$(/usr/bin/xcrun -sdk macosx -f metal 2>/dev/null || true)"
  metallib_path="$(/usr/bin/xcrun -sdk macosx -f metallib 2>/dev/null || true)"
  if [[ -n "$metal_path" && -x "$metal_path" && -n "$metallib_path" && -x "$metallib_path" ]]; then
    return 0
  fi

  if [[ "${SKIP_METAL_TOOLCHAIN_DOWNLOAD:-0}" == "1" ]]; then
    print -u2 "錯誤：找不到 Xcode Metal Toolchain（metal / metallib）。"
    print -u2 "請執行：xcodebuild -downloadComponent MetalToolchain"
    exit 1
  fi

  print -u2 "尚未安裝 Xcode Metal Toolchain，正在透過 Xcode 下載必要元件…"
  if ! /usr/bin/xcodebuild -downloadComponent MetalToolchain; then
    print -u2 "錯誤：Metal Toolchain 下載失敗。"
    print -u2 "請確認 Xcode 授權已接受，並手動執行："
    print -u2 "  sudo xcodebuild -license accept"
    print -u2 "  xcodebuild -downloadComponent MetalToolchain"
    exit 1
  fi

  /usr/bin/xcrun --kill-cache 2>/dev/null || true
  metal_path="$(/usr/bin/xcrun -sdk macosx -f metal 2>/dev/null || true)"
  metallib_path="$(/usr/bin/xcrun -sdk macosx -f metallib 2>/dev/null || true)"
  if [[ -z "$metal_path" || ! -x "$metal_path" || -z "$metallib_path" || ! -x "$metallib_path" ]]; then
    print -u2 "錯誤：Metal Toolchain 已下載，但 xcrun 仍找不到 metal / metallib。"
    print -u2 "目前 Xcode 路徑：$(/usr/bin/xcode-select -p 2>/dev/null || print '未設定')"
    print -u2 "請執行：sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
    exit 1
  fi

  print "Xcode Metal Toolchain 安裝完成。"
}

CREATE_DMG=true
if [[ "${1:-}" == "--no-dmg" ]]; then
  CREATE_DMG=false
  shift
fi

if (( $# > 0 )); then
  print -u2 "用法：$0 [--no-dmg]"
  exit 2
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  print -u2 "錯誤：GenImage 目前僅支援 macOS。"
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  print -u2 "錯誤：GenImage 需要 Apple Silicon（arm64）。"
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  print -u2 "錯誤：找不到 Swift。請先安裝 Xcode，並完成 Command Line Tools 設定。"
  exit 1
fi

if [[ "$CREATE_DMG" == true && ! -x /usr/bin/hdiutil ]]; then
  print -u2 "錯誤：找不到 macOS hdiutil，無法製作 DMG。"
  exit 1
fi

ensure_metal_toolchain

print "正在編譯 GenImage Release 版本…"
swift build -c release

QWEN_WORKER_PACKAGE="$SCRIPT_DIR/RuntimeSupport/Qwen2511Worker"
print "正在編譯 Qwen Image Edit 2511 Runtime Worker…"
swift build --package-path "$QWEN_WORKER_PACKAGE" -c release
QWEN_WORKER_BIN_DIR="$(swift build --package-path "$QWEN_WORKER_PACKAGE" -c release --show-bin-path)"
QWEN_WORKER="$QWEN_WORKER_BIN_DIR/GenImageQwen2511Worker"
if [[ ! -x "$QWEN_WORKER" ]]; then
  print -u2 "錯誤：找不到 Qwen 2511 Runtime Worker：$QWEN_WORKER"
  exit 1
fi

QWEN_METALLIB_SCRIPT="$SCRIPT_DIR/.build/checkouts/Z-Image.swift/scripts/build_mlx_metallib.sh"
QWEN_MLX_SWIFT="$QWEN_WORKER_PACKAGE/.build/checkouts/mlx-swift"
QWEN_METALLIB="$QWEN_WORKER_BIN_DIR/mlx.metallib"
if [[ ! -x "$QWEN_METALLIB_SCRIPT" || ! -d "$QWEN_MLX_SWIFT" ]]; then
  print -u2 "錯誤：找不到 Qwen Worker 的 MLX Metal 編譯來源。"
  exit 1
fi
"$QWEN_METALLIB_SCRIPT" \
  --configuration release \
  --project-root "$QWEN_WORKER_PACKAGE" \
  --mlx-swift-path "$QWEN_MLX_SWIFT" \
  --bin-path "$QWEN_WORKER_BIN_DIR" \
  --output "$QWEN_METALLIB" \
  --deployment-target 26.0

BIN_DIR="$(swift build -c release --show-bin-path)"
METALLIB_SOURCE="$SCRIPT_DIR/RuntimeSupport/mlx.metallib"
METALLIB_TARGET="$BIN_DIR/mlx.metallib"

if [[ ! -f "$METALLIB_SOURCE" ]]; then
  print -u2 "錯誤：找不到 MLX Metal Runtime：$METALLIB_SOURCE"
  exit 1
fi

cp "$METALLIB_SOURCE" "$METALLIB_TARGET"

if [[ "$CREATE_DMG" == true ]]; then
  APP_NAME="GenImage"
  APP_VERSION="${GENIMAGE_VERSION:-1.0.0}"
  BUNDLE_ID="${GENIMAGE_BUNDLE_ID:-com.vader.genimage}"
  BUILD_NUMBER="$(date '+%Y%m%d%H%M')"
  DIST_DIR="$SCRIPT_DIR/dist"
  APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
  CONTENTS_DIR="$APP_BUNDLE/Contents"
  MACOS_DIR="$CONTENTS_DIR/MacOS"
  HELPERS_DIR="$CONTENTS_DIR/Helpers"
  RESOURCES_DIR="$CONTENTS_DIR/Resources"
  PLIST_PATH="$CONTENTS_DIR/Info.plist"
  DMG_PATH="$DIST_DIR/${APP_NAME}-${APP_VERSION}-arm64.dmg"
  TEMP_ROOT="${TMPDIR:-/tmp}"
  DMG_WORK_DIR="$(mktemp -d "${TEMP_ROOT%/}/genimage-dmg.XXXXXX")"
  DMG_ROOT="$DMG_WORK_DIR/root"
  TEMP_DMG_PATH="$DMG_WORK_DIR/${DMG_PATH:t}"

  cleanup_dmg_work_dir() {
    rm -rf -- "$DMG_WORK_DIR"
  }
  trap cleanup_dmg_work_dir EXIT INT TERM

  print "正在建立 $APP_NAME.app…"
  mkdir -p "$DIST_DIR"
  rm -rf -- "$APP_BUNDLE" "$DIST_DIR/.dmg-root"
  rm -f -- "$DMG_PATH"
  mkdir -p "$MACOS_DIR" "$HELPERS_DIR" "$RESOURCES_DIR"

  /usr/bin/ditto "$BIN_DIR/GenImage" "$MACOS_DIR/GenImage"
  /usr/bin/ditto "$BIN_DIR/GenImageMCP" "$HELPERS_DIR/GenImageMCP"
  /usr/bin/ditto "$BIN_DIR/GenImageDoctor" "$HELPERS_DIR/GenImageDoctor"
  /usr/bin/ditto "$QWEN_WORKER" "$HELPERS_DIR/GenImageQwen2511Worker"
  /usr/bin/ditto "$METALLIB_SOURCE" "$MACOS_DIR/mlx.metallib"
  /usr/bin/ditto "$QWEN_METALLIB" "$HELPERS_DIR/mlx.metallib"
  chmod 755 \
    "$MACOS_DIR/GenImage" \
    "$HELPERS_DIR/GenImageMCP" \
    "$HELPERS_DIR/GenImageDoctor" \
    "$HELPERS_DIR/GenImageQwen2511Worker"

  typeset -a RESOURCE_BUNDLES
  RESOURCE_BUNDLES=("$BIN_DIR"/*.bundle(N))
  if (( ${#RESOURCE_BUNDLES[@]} == 0 )); then
    print -u2 "錯誤：找不到 SwiftPM 資源 bundle。"
    exit 1
  fi
  for resource_bundle in "${RESOURCE_BUNDLES[@]}"; do
    /usr/bin/ditto "$resource_bundle" "$APP_BUNDLE/${resource_bundle:t}"
  done

  typeset -a QWEN_RESOURCE_BUNDLES
  QWEN_RESOURCE_BUNDLES=("$QWEN_WORKER_BIN_DIR"/*.bundle(N))
  for resource_bundle in "${QWEN_RESOURCE_BUNDLES[@]}"; do
    /usr/bin/ditto "$resource_bundle" "$HELPERS_DIR/${resource_bundle:t}"
  done

  /usr/bin/plutil -create xml1 "$PLIST_PATH"
  /usr/bin/plutil -insert CFBundleDevelopmentRegion -string "zh_TW" "$PLIST_PATH"
  /usr/bin/plutil -insert CFBundleDisplayName -string "$APP_NAME" "$PLIST_PATH"
  /usr/bin/plutil -insert CFBundleExecutable -string "GenImage" "$PLIST_PATH"
  /usr/bin/plutil -insert CFBundleIdentifier -string "$BUNDLE_ID" "$PLIST_PATH"
  /usr/bin/plutil -insert CFBundleInfoDictionaryVersion -string "6.0" "$PLIST_PATH"
  /usr/bin/plutil -insert CFBundleName -string "$APP_NAME" "$PLIST_PATH"
  /usr/bin/plutil -insert CFBundlePackageType -string "APPL" "$PLIST_PATH"
  /usr/bin/plutil -insert CFBundleShortVersionString -string "$APP_VERSION" "$PLIST_PATH"
  /usr/bin/plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$PLIST_PATH"
  /usr/bin/plutil -insert LSApplicationCategoryType -string "public.app-category.graphics-design" "$PLIST_PATH"
  /usr/bin/plutil -insert LSMinimumSystemVersion -string "14.0" "$PLIST_PATH"
  /usr/bin/plutil -insert LSRequiresNativeExecution -bool YES "$PLIST_PATH"
  /usr/bin/plutil -insert NSHighResolutionCapable -bool YES "$PLIST_PATH"
  /usr/bin/plutil -insert NSPrincipalClass -string "NSApplication" "$PLIST_PATH"

  find "$APP_BUNDLE" -name '._*' -delete
  /usr/bin/xattr -cr "$APP_BUNDLE" 2>/dev/null || true

  # SwiftPM 產生的 resource accessor 會從 App 根目錄讀取 *.bundle。
  # 這個結構可正常執行，但不符合 Developer ID 的嚴格根目錄封裝規則，
  # 因此此階段不對整個 App bundle 做簽章，避免產生不完整簽章。

  print "正在製作 $DMG_PATH…"
  mkdir -p "$DMG_ROOT"
  /usr/bin/ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
  ln -s /Applications "$DMG_ROOT/Applications"
  find "$DMG_ROOT" -name '._*' -delete

  /usr/bin/hdiutil create \
    -volname "$APP_NAME $APP_VERSION" \
    -srcfolder "$DMG_ROOT" \
    -format UDZO \
    -ov \
    "$TEMP_DMG_PATH"
  /usr/bin/hdiutil verify "$TEMP_DMG_PATH"
  mv -- "$TEMP_DMG_PATH" "$DMG_PATH"
  cleanup_dmg_work_dir
  trap - EXIT INT TERM
fi

print ""
print "編譯完成。"
print "GenImage：$BIN_DIR/GenImage"
print "GenImage MCP：$BIN_DIR/GenImageMCP"
print "模型診斷工具：$BIN_DIR/GenImageDoctor"
print "Qwen 2511 Runtime：$QWEN_WORKER"
print "MLX Metal Runtime：$METALLIB_TARGET"
if [[ "$CREATE_DMG" == true ]]; then
  print "App Bundle：$APP_BUNDLE"
  print "DMG：$DMG_PATH"
fi
