#!/usr/bin/env bash
# Build Debug WisperClone and launch it (fresh process). Use after agent edits so you can observe UI.
#
#   ./run-debug.sh           — kill running app, incremental build, open
#   ./run-debug.sh --clean   — same, but xcodebuild clean first (fresh compile)
#   ./run-debug.sh --purge   — delete local .derivedData, then full build (nuclear)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

DERIVED="$PROJECT_ROOT/.derivedData"
APP_PATH="$DERIVED/Build/Products/Debug/WisperClone.app"

if [[ ! -f "$PROJECT_ROOT/WisperClone.xcodeproj/project.pbxproj" ]]; then
  echo "error: run from repo; expected WisperClone.xcodeproj under $PROJECT_ROOT" >&2
  exit 1
fi

do_clean=false
do_purge=false
for arg in "$@"; do
  case "$arg" in
    --clean) do_clean=true ;;
    --purge) do_purge=true ;;
    -h|--help)
      echo "usage: $0 [--clean | --purge]"
      echo "  (default)  kill WisperClone, incremental Debug build, open app"
      echo "  --clean    xcodebuild clean before build"
      echo "  --purge    remove .derivedData, then clean + build"
      exit 0
      ;;
    *)
      echo "usage: $0 [--clean | --purge]" >&2
      exit 1
      ;;
  esac
done

# Replace a running instance so you always see the new build.
if pgrep -xq "WisperClone"; then
  killall "WisperClone" 2>/dev/null || true
  sleep 0.3
fi

if [[ "$do_purge" == true ]]; then
  rm -rf "$DERIVED"
fi

XCB=(xcodebuild
  -project WisperClone.xcodeproj
  -scheme WisperClone
  -configuration Debug
  -destination "platform=macOS"
  -derivedDataPath "$DERIVED")

if [[ "$do_clean" == true || "$do_purge" == true ]]; then
  "${XCB[@]}" clean
fi

"${XCB[@]}" build

open "$APP_PATH"
echo "Launched: $APP_PATH"
