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

PACKAGE_APP=true
CREATE_DMG=true
case "${1:-}" in
  --no-dmg)
    PACKAGE_APP=false
    CREATE_DMG=false
    shift
    ;;
  --app-only)
    CREATE_DMG=false
    shift
    ;;
esac

if (( $# > 0 )); then
  print -u2 "用法：$0 [--no-dmg|--app-only]"
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

if [[ "$PACKAGE_APP" == true && ! -x /usr/bin/codesign ]]; then
  print -u2 "錯誤：找不到 macOS codesign，無法簽署 App。"
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

if [[ "$PACKAGE_APP" == true ]]; then
  APP_NAME="GenImage"
  APP_VERSION="${GENIMAGE_VERSION:-$(date '+1.%y.%m%d')}"
  BUNDLE_ID="${GENIMAGE_BUNDLE_ID:-com.vader.genimage}"
  BUILD_NUMBER="${GENIMAGE_BUILD_NUMBER:-$(date '+%H%M')}"
  CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
  DIST_DIR="$SCRIPT_DIR/dist"
  FINAL_APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
  STAGED_APP_BUNDLE="$DIST_DIR/.$APP_NAME.app.building.$$"
  APP_BUNDLE="$STAGED_APP_BUNDLE"
  CONTENTS_DIR="$APP_BUNDLE/Contents"
  MACOS_DIR="$CONTENTS_DIR/MacOS"
  HELPERS_DIR="$CONTENTS_DIR/Helpers"
  RESOURCES_DIR="$CONTENTS_DIR/Resources"
  SWIFTPM_RESOURCES_DIR="$RESOURCES_DIR"
  QWEN_RESOURCES_DIR="$HELPERS_DIR"
  LICENSES_DIR="$RESOURCES_DIR/Licenses"
  PLIST_PATH="$CONTENTS_DIR/Info.plist"
  DMG_PATH="$DIST_DIR/${APP_NAME}-${APP_VERSION}-arm64.dmg"

  if [[ ! "$APP_VERSION" =~ '^[0-9]+([.][0-9]+)*$' ]]; then
    print -u2 "錯誤：GENIMAGE_VERSION 必須是數字與句點組成的版本號：$APP_VERSION"
    exit 1
  fi
  if [[ ! "$BUILD_NUMBER" =~ '^[0-9]{4}$' ]]; then
    print -u2 "錯誤：GENIMAGE_BUILD_NUMBER 必須是 HHmm 四位數字：$BUILD_NUMBER"
    exit 1
  fi

  cleanup_staged_app() {
    rm -rf -- "$STAGED_APP_BUNDLE"
  }

  replace_app_bundle() {
    local previous_app_bundle="$DIST_DIR/.$APP_NAME.app.previous.$$"
    local running_pids=""
    running_pids="$(/usr/bin/pgrep -x "$APP_NAME" 2>/dev/null || true)"
    if [[ -n "$running_pids" ]]; then
      print -u2 "錯誤：偵測到仍在執行的 $APP_NAME（PID：${running_pids//$'\n'/, }）。"
      print -u2 "請先結束舊版 App 再重新建置，避免已啟動的程式被留在已刪除的 App Bundle。"
      return 1
    fi
    rm -rf -- "$previous_app_bundle"
    if [[ -e "$FINAL_APP_BUNDLE" ]]; then
      mv -- "$FINAL_APP_BUNDLE" "$previous_app_bundle"
    fi
    if mv -- "$STAGED_APP_BUNDLE" "$FINAL_APP_BUNDLE"; then
      rm -rf -- "$previous_app_bundle"
      return 0
    fi
    if [[ -e "$previous_app_bundle" ]]; then
      mv -- "$previous_app_bundle" "$FINAL_APP_BUNDLE"
    fi
    print -u2 "錯誤：無法將完成的 App Bundle 發佈至 $FINAL_APP_BUNDLE"
    return 1
  }

  trap cleanup_staged_app EXIT INT TERM

  print "正在建立 $APP_NAME.app…"
  mkdir -p "$DIST_DIR"
  rm -rf -- "$STAGED_APP_BUNDLE" "$DIST_DIR/.dmg-root"
  rm -f -- "$DMG_PATH"
  mkdir -p \
    "$MACOS_DIR" \
    "$HELPERS_DIR" \
    "$RESOURCES_DIR/WebUI" \
    "$SWIFTPM_RESOURCES_DIR" \
    "$QWEN_RESOURCES_DIR" \
    "$LICENSES_DIR"

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

  APP_RESOURCE_BUNDLE="$BIN_DIR/GenImage_GenImageApp.bundle"
  WEBUI_SOURCE=""
  for webui_candidate in \
    "$APP_RESOURCE_BUNDLE/Contents/Resources/WebUI" \
    "$APP_RESOURCE_BUNDLE/WebUI"; do
    if [[ -s "$webui_candidate/index.html" ]]; then
      WEBUI_SOURCE="$webui_candidate"
      break
    fi
  done
  if [[ -z "$WEBUI_SOURCE" ]]; then
    print -u2 "錯誤：找不到 WebUI 資源：$APP_RESOURCE_BUNDLE"
    exit 1
  fi
  /usr/bin/ditto "$WEBUI_SOURCE" "$RESOURCES_DIR/WebUI"
  if [[ ! -s "$RESOURCES_DIR/WebUI/index.html" ]] || ! /usr/bin/diff -qr "$WEBUI_SOURCE" "$RESOURCES_DIR/WebUI" >/dev/null; then
    print -u2 "錯誤：WebUI 資源複製不完整。"
    exit 1
  fi

  typeset -a RESOURCE_BUNDLES
  RESOURCE_BUNDLES=("$BIN_DIR"/*.bundle(N))
  if (( ${#RESOURCE_BUNDLES[@]} == 0 )); then
    print -u2 "錯誤：找不到 SwiftPM 資源 bundle。"
    exit 1
  fi
  for resource_bundle in "${RESOURCE_BUNDLES[@]}"; do
    if [[ "$resource_bundle" != "$APP_RESOURCE_BUNDLE" ]]; then
      /usr/bin/ditto "$resource_bundle" "$SWIFTPM_RESOURCES_DIR/${resource_bundle:t}"
    fi
  done

  typeset -a QWEN_RESOURCE_BUNDLES
  QWEN_RESOURCE_BUNDLES=("$QWEN_WORKER_BIN_DIR"/*.bundle(N))
  for resource_bundle in "${QWEN_RESOURCE_BUNDLES[@]}"; do
    /usr/bin/ditto "$resource_bundle" "$QWEN_RESOURCES_DIR/${resource_bundle:t}"
  done
  /usr/bin/ditto "$SCRIPT_DIR/LICENSE" "$LICENSES_DIR/GPL-3.0.txt"

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
  find "$APP_BUNDLE" -name '.DS_Store' -delete
  find "$APP_BUNDLE" -name '_CodeSignature' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$APP_BUNDLE" -name 'CodeResources' -type f -delete 2>/dev/null || true
  /usr/bin/xattr -cr "$APP_BUNDLE" 2>/dev/null || true

  typeset -a SIGNING_ARGUMENTS
  SIGNING_ARGUMENTS=(--force --sign "$CODESIGN_IDENTITY" --options runtime)
  if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
    SIGNING_ARGUMENTS+=(--timestamp)
    print "正在以 Developer ID Application 簽署 App…"
  else
    print "正在以 ad-hoc 簽章簽署本機 App…"
  fi

  typeset -a NESTED_RESOURCE_BUNDLES
  NESTED_RESOURCE_BUNDLES=(
    "$RESOURCES_DIR"/*.bundle(N)
    "$HELPERS_DIR"/*.bundle(N)
  )
  for resource_bundle in "${NESTED_RESOURCE_BUNDLES[@]}"; do
    /usr/bin/codesign "${SIGNING_ARGUMENTS[@]}" "$resource_bundle"
  done

  for code_object in \
    "$MACOS_DIR/mlx.metallib" \
    "$HELPERS_DIR/mlx.metallib" \
    "$HELPERS_DIR/GenImageMCP" \
    "$HELPERS_DIR/GenImageDoctor" \
    "$HELPERS_DIR/GenImageQwen2511Worker" \
    "$MACOS_DIR/GenImage"; do
    /usr/bin/codesign "${SIGNING_ARGUMENTS[@]}" "$code_object"
  done
  /usr/bin/codesign "${SIGNING_ARGUMENTS[@]}" "$APP_BUNDLE"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

  replace_app_bundle
  trap - EXIT INT TERM
  APP_BUNDLE="$FINAL_APP_BUNDLE"

  if [[ "$CREATE_DMG" == true ]]; then
    TEMP_ROOT="${TMPDIR:-/tmp}"
    DMG_WORK_DIR="$(mktemp -d "${TEMP_ROOT%/}/genimage-dmg.XXXXXX")"
    DMG_ROOT="$DMG_WORK_DIR/root"
    TEMP_DMG_PATH="$DMG_WORK_DIR/${DMG_PATH:t}"

    cleanup_dmg_work_dir() {
      rm -rf -- "$DMG_WORK_DIR"
    }
    trap cleanup_dmg_work_dir EXIT INT TERM

    print "正在製作 $DMG_PATH…"
    mkdir -p "$DMG_ROOT"
    /usr/bin/ditto --extattr --noqtn "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
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
    if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
      /usr/bin/codesign --force --sign "$CODESIGN_IDENTITY" --timestamp "$DMG_PATH"
      /usr/bin/codesign --verify --strict --verbose=2 "$DMG_PATH"
    fi
    cleanup_dmg_work_dir
    trap - EXIT INT TERM
  fi
fi

print ""
print "編譯完成。"
print "GenImage：$BIN_DIR/GenImage"
print "GenImage MCP：$BIN_DIR/GenImageMCP"
print "模型診斷工具：$BIN_DIR/GenImageDoctor"
print "Qwen 2511 Runtime：$QWEN_WORKER"
print "MLX Metal Runtime：$METALLIB_TARGET"
if [[ "$PACKAGE_APP" == true ]]; then
  print "App Bundle：$APP_BUNDLE"
fi
if [[ "$CREATE_DMG" == true ]]; then
  print "DMG：$DMG_PATH"
fi
