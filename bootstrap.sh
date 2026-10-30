#!/usr/bin/env bash
set -euo pipefail

readonly VM_NAME=dev
# Lima's shared SSH connection adds typing latency, so use dedicated local sessions.
readonly VM_SSH='ssh -o ControlPath=none -o ControlPersist=no -o ObscureKeystrokeTiming=no'
readonly TERMINAL_PROFILE=NixOS
readonly WORK_EMAIL_DOMAIN=shamaazi.com
readonly GCLPR_VERSION=2.3.1
readonly GCLPR_SHA256=a9c7d309122e1fa3bef1dd1313f5954f55a3527d82300ae868277b7195bb3f6e
readonly GCLPR_BINARY_SHA256=2e1ef2428237322ea85536e714003b43efbb936165313476bce4f79a25544742
readonly GCLPR_DIR="$HOME/Library/Application Support/Machines/gclpr"
readonly GCLPR_BIN="$GCLPR_DIR/gclpr"
readonly GCLPR_PLIST="$HOME/Library/LaunchAgents/com.shamaazi.machines.gclpr.plist"

gclpr_changed=false

assert() {
  local message=$1
  shift
  if ! "$@"; then
    printf '%s\n' "$message" >&2
    exit 1
  fi
}

create_temporary_directory() {
  bootstrap_tmp=$(mktemp -d -t machines-bootstrap)
  trap 'rm -r -- "$bootstrap_tmp"' EXIT
}

check_platform() {
  assert 'Machines requires an Apple Silicon Mac.' test "$(uname -sm)" = 'Darwin arm64'
}

install_lima() {
  command -v limactl >/dev/null 2>&1 && return

  local archive="$bootstrap_tmp/lima.tar.gz"
  curl --fail --location --retry 3 --output "$archive" \
    https://github.com/lima-vm/lima/releases/download/v2.2.1/lima-2.2.1-Darwin-arm64.tar.gz
  printf '%s  %s\n' 9e9eacce88f37e185c346bad73aa6136f738d8cdf8c3bb23cd42b071824bc66e \
    "$archive" | shasum -a 256 --check
  sudo mkdir -p /usr/local
  sudo tar -xzf "$archive" -C /usr/local
}

create_vm() {
  [ -f "$HOME/.lima/$VM_NAME/lima.yaml" ] && return

  local cpus memory_bytes memory_gib
  cpus=$(sysctl -n hw.ncpu)
  memory_bytes=$(sysctl -n hw.memsize)
  memory_gib=$((memory_bytes / 1024 / 1024 / 1024 - 8))
  assert 'Machines needs more than 8 GiB RAM to leave 8 GiB for macOS.' \
    test "$memory_gib" -ge 1

  limactl create --yes --name "$VM_NAME" --cpus "$cpus" --memory "$memory_gib" \
    https://raw.githubusercontent.com/shamaazi/machines/main/lima.yaml </dev/null
}

start_vm() {
  limactl start --yes "$VM_NAME" </dev/null
}

check_vm_has_gclpr() {
  assert 'The VM must be rebuilt with gclpr before installing the Mac integration.' \
    limactl shell "$VM_NAME" -- sh -c 'command -v gclpr >/dev/null'
}

install_mac_gclpr() {
  local archive="$bootstrap_tmp/gclpr.zip"
  local unpack="$bootstrap_tmp/gclpr"

  install -d -m 700 "$GCLPR_DIR" "$HOME/.gclpr"
  mkdir -p "$HOME/Library/LaunchAgents"
  if [ -x "$GCLPR_BIN" ] && \
    printf '%s  %s\n' "$GCLPR_BINARY_SHA256" "$GCLPR_BIN" | \
      shasum -a 256 --check --status; then
    return
  fi

  mkdir "$unpack"

  curl --fail --location --retry 3 --output "$archive" \
    "https://github.com/rupor-github/gclpr/releases/download/v${GCLPR_VERSION}/gclpr_darwin_arm64.zip"
  printf '%s  %s\n' "$GCLPR_SHA256" "$archive" | shasum -a 256 --check
  ditto -x -k "$archive" "$unpack"

  install -m 700 "$unpack/gclpr" "$GCLPR_BIN.new"
  mv -f "$GCLPR_BIN.new" "$GCLPR_BIN"
  gclpr_changed=true
}

ensure_vm_gclpr_key() {
  # Expand HOME in the guest, not in this Mac shell.
  # shellcheck disable=SC2016
  limactl shell "$VM_NAME" -- sh -c \
    'test -f "$HOME/.gclpr/key" && test -f "$HOME/.gclpr/key.pub"' && return

  limactl shell "$VM_NAME" -- gclpr genkey >/dev/null
}

trust_vm_gclpr_key() {
  local public_key
  # shellcheck disable=SC2016
  public_key=$(limactl shell "$VM_NAME" -- sh -c \
    'od -An -v -tx1 "$HOME/.gclpr/key.pub"' | tr -d '[:space:]')
  assert 'Could not read the gclpr public key from the VM.' \
    grep -Eq '^[0-9a-f]{64}$' <<< "$public_key"

  # This server is exclusively for the VM, so replace stale trusted keys.
  install -m 600 /dev/stdin "$HOME/.gclpr/trusted" <<< "$public_key"
}

install_gclpr_launch_agent() {
  local desired_plist="$bootstrap_tmp/gclpr.plist"
  local service
  service="gui/$(id -u)/com.shamaazi.machines.gclpr"

  cat > "$desired_plist" <<GCLPR_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.shamaazi.machines.gclpr</string>
  <key>ProgramArguments</key>
  <array>
    <string>$GCLPR_BIN</string>
    <string>server</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
GCLPR_PLIST

  plutil -lint "$desired_plist" >/dev/null
  # Do not interrupt a healthy bridge when its binary and service definition are unchanged.
  if [ "$gclpr_changed" = false ] && [ -f "$GCLPR_PLIST" ] && \
    cmp -s "$desired_plist" "$GCLPR_PLIST" && \
    launchctl print "$service" >/dev/null 2>&1; then
    return
  fi

  install -m 644 "$desired_plist" "$GCLPR_PLIST"
  launchctl bootout "$service" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$GCLPR_PLIST"
}

configure_host_integration() {
  check_vm_has_gclpr
  install_mac_gclpr
  ensure_vm_gclpr_key
  trust_vm_gclpr_key
  install_gclpr_launch_agent
}

configure_github() {
  if ! limactl shell "$VM_NAME" -- gh auth status --hostname github.com >/dev/null 2>&1; then
    limactl shell "$VM_NAME" -- gh auth login --hostname github.com \
      --git-protocol https --web --scopes user:email </dev/tty
  elif ! limactl shell "$VM_NAME" -- gh api user/emails --silent >/dev/null 2>&1; then
    limactl shell "$VM_NAME" -- gh auth refresh --hostname github.com \
      --scopes user:email </dev/tty
  fi

  local profile github_login github_id github_name git_name git_email
  profile=$(limactl shell "$VM_NAME" -- gh api user --jq \
    '[.login, (.id | tostring), (.name // "")] | join("\u001f")')
  IFS=$'\x1f' read -r github_login github_id github_name <<< "$profile"

  git_name=$github_name
  if [ -z "$git_name" ]; then
    git_name=$github_login
    printf 'Warning: GitHub has no profile name; using %s. Update it and rerun bootstrap.\n' \
      "$git_name" >&2
  fi

  git_email=$(limactl shell "$VM_NAME" -- gh api 'user/emails?per_page=100' --jq \
    "[.[] | select(.verified and (.email | ascii_downcase | endswith(\"@${WORK_EMAIL_DOMAIN}\")))] | sort_by(if .primary then 0 else 1 end) | (.[0].email // \"\")")
  if [ -z "$git_email" ]; then
    git_email="${github_id}+${github_login}@users.noreply.github.com"
    printf 'Warning: GitHub has no verified @%s email; using %s. Add one and rerun bootstrap.\n' \
      "$WORK_EMAIL_DOMAIN" "$git_email" >&2
  fi

  limactl shell "$VM_NAME" -- git config --global user.name "$git_name"
  limactl shell "$VM_NAME" -- git config --global user.email "$git_email"
  printf 'Git identity: %s <%s>\n' "$git_name" "$git_email"
}

configure_ssh() {
  local ssh_include="Include \"$HOME/.lima/$VM_NAME/ssh.config\""
  # Expose Lima's generated host to standard SSH clients such as editors and Codex.
  install -d -m 700 "$HOME/.ssh"
  grep -Fxq "$ssh_include" "$HOME/.ssh/config" 2>/dev/null || \
    printf '\n%s\n' "$ssh_include" >> "$HOME/.ssh/config"
  chmod 600 "$HOME/.ssh/config"
}

enable_vm_autostart() {
  limactl autostart enable "$VM_NAME" </dev/null
}

configure_terminal_profile() {
  local profile="$bootstrap_tmp/terminal.plist"
  local appearance
  appearance=$(defaults read com.apple.Terminal 'Default Window Settings' 2>/dev/null || true)

  # Copy the current appearance; a minimal profile falls back to a white background.
  if ! defaults export com.apple.Terminal - 2>/dev/null | \
    plutil -extract "Window Settings.$appearance" xml1 -o "$profile" - 2>/dev/null; then
    printf '%s\n' \
      '{ type = "Window Settings"; name = ""; CommandString = ""; RunCommandAsShell = 0; warnOnShellCloseAction = 0; }' \
      > "$profile"
  fi
  plutil -convert xml1 "$profile"

  plutil -replace name -string "$TERMINAL_PROFILE" "$profile"
  plutil -replace CommandString -string \
    "SSH='$VM_SSH' limactl shell --start $VM_NAME" "$profile"
  plutil -replace RunCommandAsShell -bool false "$profile"
  plutil -replace warnOnShellCloseAction -integer 0 "$profile"

  defaults write com.apple.Terminal 'Window Settings' \
    -dict-add "$TERMINAL_PROFILE" "$(cat "$profile")"
  defaults write com.apple.Terminal 'Default Window Settings' -string "$TERMINAL_PROFILE"
  defaults write com.apple.Terminal 'Startup Window Settings' -string "$TERMINAL_PROFILE"
}

# Main program

check_platform
create_temporary_directory
install_lima
create_vm
start_vm
configure_host_integration
configure_github
configure_ssh
enable_vm_autostart
configure_terminal_profile

printf 'Setup complete. Reopen Terminal and open a new %s window.\n' "$TERMINAL_PROFILE"
printf 'Editors and Codex can connect using SSH host lima-dev.\n'
