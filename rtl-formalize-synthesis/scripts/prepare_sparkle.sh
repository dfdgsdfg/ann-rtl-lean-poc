#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/vendor/Sparkle"
PATCH_FILE="$ROOT_DIR/patches/sparkle-local.patch"
SPARKLE_URL="https://github.com/Verilean/sparkle"
SPARKLE_REV="2d3dda875b0aa12d850322f26a2c42a9379931c8"

if ! command -v git >/dev/null 2>&1; then
  echo "missing required tool: git" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/vendor"

if [ -e "$VENDOR_DIR" ] && [ ! -d "$VENDOR_DIR/.git" ]; then
  rm -rf "$VENDOR_DIR"
fi

if [ ! -d "$VENDOR_DIR/.git" ]; then
  git clone "$SPARKLE_URL" "$VENDOR_DIR"
fi

git -C "$VENDOR_DIR" fetch --tags origin
git -C "$VENDOR_DIR" checkout --detach "$SPARKLE_REV"
git -C "$VENDOR_DIR" reset --hard "$SPARKLE_REV"
git -C "$VENDOR_DIR" clean -fdx
git -C "$VENDOR_DIR" apply "$PATCH_FILE"
