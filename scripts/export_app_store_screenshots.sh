#!/bin/zsh

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <xcresult-path> [locale] [device-class]" >&2
  exit 1
fi

XCRESULT_PATH="$1"
LOCALE="${2:-en-US}"
DEVICE_CLASS="${3:-iphone-6.9}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEST_DIR="$ROOT_DIR/marketing/app_store/screenshots/$DEVICE_CLASS/$LOCALE/raw"
TMP_DIR="$(mktemp -d /tmp/resetminute_xcresult_export.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$DEST_DIR"

xcrun xcresulttool export attachments --path "$XCRESULT_PATH" --output-path "$TMP_DIR" >/dev/null

/usr/bin/ruby - "$TMP_DIR/manifest.json" "$TMP_DIR" "$DEST_DIR" <<'RUBY'
require "json"
require "fileutils"

manifest_path = ARGV[0]
tmp_dir = ARGV[1]
dest_dir = ARGV[2]

manifest = JSON.parse(File.read(manifest_path))

manifest.each do |entry|
  entry.fetch("attachments", []).each do |attachment|
    exported = attachment.fetch("exportedFileName")
    suggested = attachment.fetch("suggestedHumanReadableName")
    ext = File.extname(suggested)
    stable_name = suggested.sub(/_\d+_[0-9A-Fa-f-]+#{Regexp.escape(ext)}\z/, ext)
    FileUtils.cp(File.join(tmp_dir, exported), File.join(dest_dir, stable_name))
  end
end
RUBY

echo "Exported screenshots to: $DEST_DIR"
ls -1 "$DEST_DIR"
