#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo 'Machines requires an Apple Silicon Mac.' >&2
  exit 1
fi

store="${MACHINES_HOME:-$HOME/.local/share/machines}"
name="${MACHINES_NAME:-dev}"
export LIMA_HOME="$store/lima"
cli="$store/runtime/bin/limactl"

if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo 'Invalid machine name.' >&2
  exit 2
fi

if [ ! -x "$cli" ]; then
  mkdir -p "$store/runtime"
  curl --fail --location --retry 3 --output "$store/lima.tar.gz" \
    https://github.com/lima-vm/lima/releases/download/v2.2.1/lima-2.2.1-Darwin-arm64.tar.gz
  printf '%s  %s\n' 9e9eacce88f37e185c346bad73aa6136f738d8cdf8c3bb23cd42b071824bc66e \
    "$store/lima.tar.gz" | shasum -a 256 --check
  tar -xzf "$store/lima.tar.gz" -C "$store/runtime"
  unlink "$store/lima.tar.gz"
fi

if [ ! -f "$LIMA_HOME/$name/lima.yaml" ]; then
  "$cli" create --yes --name "$name" \
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
printf 'Editors and Codex: SSH host lima-%s\n' "$name"

# Lima's detached SSH master needs the real terminal device, not /dev/tty.
terminal=$(tty <&2)
exec "$cli" shell "$name" < "$terminal"
