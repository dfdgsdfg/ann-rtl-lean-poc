#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/vendor"
DOWNLOAD_DIR="$VENDOR_DIR/.downloads"

SPOT_VERSION="2.14.5"
SPOT_ARCHIVE_URL="https://www.lre.epita.fr/dload/spot/spot-${SPOT_VERSION}.tar.gz"
SPOT_ARCHIVE_SHA256="8703d33426eea50a8e3b7f4b984c05b8058cbff054b260863a1688980d8b8d19"
SPOT_SRC_DIR="$VENDOR_DIR/spot-src"
SPOT_INSTALL_DIR="$VENDOR_DIR/spot-install"

SYFCO_REV="e9cff1cf39916d080ac5416ea2854bb747735f3a"
SYFCO_ARCHIVE_URL="https://github.com/reactive-systems/syfco/archive/${SYFCO_REV}.tar.gz"
SYFCO_ARCHIVE_SHA256="5e94ef1c734c1045f4531563eef32fa09cfbe0227b5427479f921c47a336c08a"
SYFCO_SRC_DIR="$VENDOR_DIR/syfco-src"
SYFCO_INSTALL_DIR="$VENDOR_DIR/syfco-install"

OPENLANE_REV="ff5509f65b17bfa4068d5336495ab1718987ff69"
OPENLANE_ARCHIVE_URL="https://github.com/The-OpenROAD-Project/OpenLane/archive/${OPENLANE_REV}.tar.gz"
OPENLANE_ARCHIVE_SHA256="f29c1b7740eb0d619b395be518f28a2099d3728a42374dba99c565f30d924073"
OPENLANE_DIR="$VENDOR_DIR/OpenLane"

requested_tools=()

usage() {
  cat <<'EOF'
Usage: scripts/prepare_vendor_tools.sh [--tool ltlsynt] [--tool syfco] [--tool openlane]

Without any --tool arguments, prepares all vendored tool trees.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tool)
      if [ $# -lt 2 ]; then
        echo "missing value for --tool" >&2
        exit 1
      fi
      requested_tools+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ ${#requested_tools[@]} -eq 0 ]; then
  requested_tools=(ltlsynt syfco openlane)
fi

mkdir -p "$DOWNLOAD_DIR"

calc_sha256() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
    return
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
    return
  fi
  echo "missing required tool: shasum or sha256sum" >&2
  exit 1
}

cpu_count() {
  if command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.ncpu
    return
  fi
  getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4
}

download_archive() {
  local url="$1"
  local sha256="$2"
  local archive_path="$3"
  local tmp_path="${archive_path}.tmp"

  if [ ! -f "$archive_path" ] || [ "$(calc_sha256 "$archive_path")" != "$sha256" ]; then
    rm -f "$archive_path" "$tmp_path"
    curl -L "$url" -o "$tmp_path"
    mv "$tmp_path" "$archive_path"
  fi

  if [ "$(calc_sha256 "$archive_path")" != "$sha256" ]; then
    echo "sha256 mismatch for $archive_path" >&2
    exit 1
  fi
}

extract_archive() {
  local archive_path="$1"
  local destination="$2"
  local marker="$3"
  local marker_path="$destination/.vendor-id"
  local temp_dir
  local extracted_dir

  if [ -f "$marker_path" ] && [ "$(cat "$marker_path")" = "$marker" ]; then
    return
  fi

  rm -rf "$destination"
  mkdir -p "$(dirname "$destination")"
  temp_dir="$(mktemp -d)"
  tar -xzf "$archive_path" -C "$temp_dir"
  extracted_dir="$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  mv "$extracted_dir" "$destination"
  printf '%s\n' "$marker" > "$marker_path"
  rm -rf "$temp_dir"
}

prepare_spot() {
  local archive_path="$DOWNLOAD_DIR/spot-${SPOT_VERSION}.tar.gz"
  local source_marker="spot-${SPOT_VERSION}"
  local install_marker="${source_marker}"

  download_archive "$SPOT_ARCHIVE_URL" "$SPOT_ARCHIVE_SHA256" "$archive_path"
  extract_archive "$archive_path" "$SPOT_SRC_DIR" "$source_marker"

  if [ -x "$SPOT_INSTALL_DIR/bin/ltlsynt" ] && [ -f "$SPOT_INSTALL_DIR/.vendor-id" ] && [ "$(cat "$SPOT_INSTALL_DIR/.vendor-id")" = "$install_marker" ]; then
    return
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "missing required tool: curl" >&2
    exit 1
  fi

  rm -rf "$SPOT_INSTALL_DIR"
  mkdir -p "$SPOT_INSTALL_DIR"
  (
    cd "$SPOT_SRC_DIR"
    ./configure --prefix="$SPOT_INSTALL_DIR" --disable-python
    make -j"$(cpu_count)"
    make install
  )
  printf '%s\n' "$install_marker" > "$SPOT_INSTALL_DIR/.vendor-id"
}

prepare_syfco() {
  local archive_path="$DOWNLOAD_DIR/syfco-${SYFCO_REV}.tar.gz"
  local source_marker="syfco-${SYFCO_REV}"
  local install_marker="${source_marker}"

  download_archive "$SYFCO_ARCHIVE_URL" "$SYFCO_ARCHIVE_SHA256" "$archive_path"
  extract_archive "$archive_path" "$SYFCO_SRC_DIR" "$source_marker"

  if [ -x "$SYFCO_INSTALL_DIR/bin/syfco" ] && [ -f "$SYFCO_INSTALL_DIR/.vendor-id" ] && [ "$(cat "$SYFCO_INSTALL_DIR/.vendor-id")" = "$install_marker" ]; then
    return
  fi

  rm -rf "$SYFCO_INSTALL_DIR"
  mkdir -p "$SYFCO_INSTALL_DIR/bin"
  (
    cd "$SYFCO_SRC_DIR"
    if command -v stack >/dev/null 2>&1; then
      STACK_ROOT="$SYFCO_SRC_DIR/.stack-root" stack install --local-bin-path "$SYFCO_INSTALL_DIR/bin"
    elif command -v cabal >/dev/null 2>&1 && command -v ghc >/dev/null 2>&1; then
      cabal v2-update
      cabal v2-install --installdir="$SYFCO_INSTALL_DIR/bin" --install-method=copy
    else
      echo "missing required tool: stack or (cabal and ghc)" >&2
      exit 1
    fi
  )
  printf '%s\n' "$install_marker" > "$SYFCO_INSTALL_DIR/.vendor-id"
}

prepare_openlane() {
  local archive_path="$DOWNLOAD_DIR/openlane-${OPENLANE_REV}.tar.gz"
  local source_marker="openlane-${OPENLANE_REV}"

  download_archive "$OPENLANE_ARCHIVE_URL" "$OPENLANE_ARCHIVE_SHA256" "$archive_path"
  extract_archive "$archive_path" "$OPENLANE_DIR" "$source_marker"
  chmod +x "$OPENLANE_DIR/flow.tcl"
}

for tool in "${requested_tools[@]}"; do
  case "$tool" in
    ltlsynt)
      prepare_spot
      ;;
    syfco)
      prepare_syfco
      ;;
    openlane)
      prepare_openlane
      ;;
    all)
      prepare_spot
      prepare_syfco
      prepare_openlane
      ;;
    *)
      echo "unknown tool selector: $tool" >&2
      exit 1
      ;;
  esac
done

