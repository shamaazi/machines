#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo 'Machines requires an Apple Silicon Mac.' >&2
  exit 1
fi
macos_version=$(sw_vers -productVersion)
if [ "${macos_version%%.*}" -lt 26 ]; then
  echo 'Machines requires macOS 26 or newer.' >&2
  exit 1
fi

source_directory="${MACHINES_REPO:-$HOME/projects/machines}"
if [ ! -e "$source_directory" ]; then
  download=$(mktemp -d -t machines-bootstrap)
  trap 'rm -rf "$download"' EXIT
  curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
    https://codeload.github.com/shamaazi/machines/tar.gz/refs/heads/main |
    tar -xz -C "$download"
  test -f "$download/machines-main/machine"
  mkdir -p "$(dirname "$source_directory")"
  mv "$download/machines-main" "$source_directory"
  rmdir "$download"
  trap - EXIT
fi
if [ ! -f "$source_directory/machine" ]; then
  echo "$source_directory already exists without the machine command; choose another MACHINES_REPO." >&2
  exit 1
fi

# Bootstrapping only needs macOS tools; all Nix builds run in Linux.
bash "$source_directory/machine" dev up </dev/null
exec bash "$source_directory/machine" dev shell </dev/tty
