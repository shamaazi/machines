#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo 'Machines requires an Apple Silicon Mac.' >&2
  exit 1
fi

if ! command -v limactl >/dev/null 2>&1; then
  archive=$(mktemp -t machines-lima)
  trap 'unlink "$archive"' EXIT
  curl --fail --location --retry 3 --output "$archive" \
    https://github.com/lima-vm/lima/releases/download/v2.2.1/lima-2.2.1-Darwin-arm64.tar.gz
  printf '%s  %s\n' 9e9eacce88f37e185c346bad73aa6136f738d8cdf8c3bb23cd42b071824bc66e \
    "$archive" | shasum -a 256 --check
  sudo mkdir -p /usr/local
  sudo tar -xzf "$archive" -C /usr/local
  unlink "$archive"
  trap - EXIT
fi

if [ ! -f "$HOME/.lima/dev/lima.yaml" ]; then
  cpus=$(sysctl -n hw.ncpu)
  memory_bytes=$(sysctl -n hw.memsize)
  memory_gib=$((memory_bytes / 1024 / 1024 / 1024 - 8))
  if [ "$memory_gib" -lt 1 ]; then
    echo 'Machines needs more than 8 GiB RAM to leave 8 GiB for macOS.' >&2
    exit 1
  fi
  limactl create --yes --name dev --cpus "$cpus" --memory "$memory_gib" \
    https://raw.githubusercontent.com/shamaazi/machines/main/lima.yaml </dev/null
fi
limactl start --yes dev </dev/null

install -d -m 700 "$HOME/.ssh"
touch "$HOME/.ssh/config"
ssh_include="Include \"$HOME/.lima/dev/ssh.config\""
if ! grep -Fxq "$ssh_include" "$HOME/.ssh/config"; then
  printf '\n%s\n' "$ssh_include" >> "$HOME/.ssh/config"
fi
chmod 600 "$HOME/.ssh/config"
limactl autostart enable dev </dev/null
# Terminal caches profiles while running; reopen it after setup to load these.
defaults write com.apple.Terminal 'Window Settings' -dict-add \
  'Dev VM' '{
    name = "Dev VM";
    type = "Window Settings";
    CommandString = "limactl shell --start dev";
  }' \
  'Mac' '{
    name = "Mac";
    type = "Window Settings";
  }'
defaults write com.apple.Terminal 'Default Window Settings' -string 'Dev VM'
defaults write com.apple.Terminal 'Startup Window Settings' -string 'Dev VM'
printf 'Terminal profiles: Dev VM (default) and Mac. Reopen Terminal to load them.\n'

printf 'Editors and Codex: SSH host lima-dev\n'

# Lima's detached SSH master needs the real terminal device, not /dev/tty.
terminal=$(tty <&2)
exec limactl shell dev < "$terminal"
