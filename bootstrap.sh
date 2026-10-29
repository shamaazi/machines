#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo 'Machines requires an Apple Silicon Mac.' >&2
  exit 1
fi

name="${MACHINES_NAME:-dev}"
export LIMA_HOME="${LIMA_HOME:-$HOME/.lima}"
cli="$HOME/.local/bin/limactl"

if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo 'Invalid machine name.' >&2
  exit 2
fi

if [ ! -x "$cli" ]; then
  mkdir -p "$HOME/.local"
  archive=$(mktemp -t machines-lima)
  trap 'unlink "$archive"' EXIT
  curl --fail --location --retry 3 --output "$archive" \
    https://github.com/lima-vm/lima/releases/download/v2.2.1/lima-2.2.1-Darwin-arm64.tar.gz
  printf '%s  %s\n' 9e9eacce88f37e185c346bad73aa6136f738d8cdf8c3bb23cd42b071824bc66e \
    "$archive" | shasum -a 256 --check
  tar -xzf "$archive" -C "$HOME/.local"
  unlink "$archive"
  trap - EXIT
fi

case "${SHELL:-/bin/zsh}" in
  */bash)
    profile="$HOME/.profile"
    if [ -f "$HOME/.bash_login" ]; then
      profile="$HOME/.bash_login"
    fi
    if [ -f "$HOME/.bash_profile" ]; then
      profile="$HOME/.bash_profile"
    fi
    ;;
  *) profile="$HOME/.zprofile" ;;
esac
# Keep these variables literal so each future login expands its own PATH.
# shellcheck disable=SC2016
path_line='export PATH="$HOME/.local/bin:$PATH"'
touch "$profile"
if ! grep -Fxq "$path_line" "$profile"; then
  printf '\n%s\n' "$path_line" >> "$profile"
fi
export PATH="$HOME/.local/bin:$PATH"

# Preserve VMs created by the earlier private-state bootstrap.
if [ ! -e "$LIMA_HOME" ] && [ -d "$HOME/.local/share/machines/lima" ]; then
  ln -s "$HOME/.local/share/machines/lima" "$LIMA_HOME"
fi

if [ ! -f "$LIMA_HOME/$name/lima.yaml" ]; then
  cpus=$(sysctl -n hw.ncpu)
  memory_bytes=$(sysctl -n hw.memsize)
  memory_gib=$((memory_bytes / 1024 / 1024 / 1024 - 8))
  if [ "$memory_gib" -lt 1 ]; then
    echo 'Machines needs more than 8 GiB RAM to leave 8 GiB for macOS.' >&2
    exit 1
  fi
  "$cli" create --yes --name "$name" --cpus "$cpus" --memory "$memory_gib" \
    https://raw.githubusercontent.com/shamaazi/machines/main/lima.yaml </dev/null
fi
"$cli" start --yes "$name" </dev/null

if ! "$cli" shell "$name" -- test -e /etc/machines-configured </dev/null; then
  "$cli" shell "$name" -- bash -s <<'GUEST'
set -euo pipefail
configuration="$HOME/.local/share/machines"
if [ ! -d "$configuration/.git" ]; then
  git clone --depth 1 https://github.com/shamaazi/machines.git "$configuration"
else
  git -C "$configuration" pull --ff-only
fi
cd "$configuration"
revision=$(nix eval --raw --impure --expr \
  '(builtins.fromJSON (builtins.readFile ./devenv.lock)).nodes.nixpkgs.locked.rev')
nix run "github:NixOS/nixpkgs/$revision#devenv" -- tasks run machine:configure
GUEST
  "$cli" restart --yes "$name" </dev/null
  "$cli" shell "$name" -- test -e /etc/machines-configured </dev/null
fi

install -d -m 700 "$HOME/.ssh"
touch "$HOME/.ssh/config"
ssh_include="Include \"$LIMA_HOME/$name/ssh.config\""
if ! grep -Fxq "$ssh_include" "$HOME/.ssh/config"; then
  printf '\n%s\n' "$ssh_include" >> "$HOME/.ssh/config"
fi
chmod 600 "$HOME/.ssh/config"
"$cli" autostart enable "$name" </dev/null
printf 'Editors and Codex: SSH host lima-%s\n' "$name"
printf 'Open a new Mac terminal to use limactl directly.\n'

# Lima's detached SSH master needs the real terminal device, not /dev/tty.
terminal=$(tty <&2)
exec "$cli" shell "$name" < "$terminal"
