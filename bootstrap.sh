#!/usr/bin/env bash
set -euo pipefail
store="${MACHINES_HOME:-$HOME/.local/share/machines}"
cli="$store/installer/Payload/bin/container"
# Unpack a verified, pinned runtime privately; onboarding needs no host Nix or sudo.
setup() {
mkdir -p "$store"
if [ ! -x "$cli" ]; then
  curl --fail --location --output "$store/container-1.6.1.pkg" \
    https://github.com/apple/container/releases/download/1.6.1/container-1.6.1-installer-signed.pkg
  printf '%s  %s\n' cd47846819f06478d067060efe21e516b562ac0a9af8eecad6d5fea0b556b200 \
    "$store/container-1.6.1.pkg" | shasum -a 256 --check
  pkgutil --check-signature "$store/container-1.6.1.pkg"
  pkgutil --expand-full "$store/container-1.6.1.pkg" "$store/installer"
fi
# Keep this runtime's state separate and avoid forwarding the Mac's SSH agent.
env -u SSH_AUTH_SOCK "$cli" system start --install-root "$store/installer/Payload" \
  --app-root "$store/state" --enable-kernel-install
"$cli" system status
}
guest() {
  # Apple's non-login transport lacks NixOS's normal shell PATH.
  "$cli" machine run -i -n "$name" --root -- "export PATH=/nix/var/nix/profiles/system/sw/bin:/run/current-system/sw/bin; $1"
}
address() {
  "$cli" machine inspect "$name" | plutil -extract 0.ipAddress raw -o - -
}
# Authorize through Apple's local root transport; no password or forwarded agent.
authorize() {
  guest 'cat >> /etc/ssh/authorized_keys; sort -u /etc/ssh/authorized_keys -o /etc/ssh/authorized_keys; chmod 644 /etc/ssh/authorized_keys'
}
ssh_config() {
  # Use dedicated keys and locally pinned host keys rather than agent forwarding.
  local host_address=$1 host_user=$2 host_port=$3 identity=$4 hosts=$5
  printf 'Host %s\n  HostName %s\n  User %s\n  Port %s\n  IdentityFile "%s"\n  UserKnownHostsFile "%s"\n  IdentitiesOnly yes\n  StrictHostKeyChecking yes\n  ForwardAgent no\n' \
    "$role" "$host_address" "$host_user" "$host_port" "$identity" "$hosts"
}
load_release() {
  # Parse public release metadata with macOS tools; no GitHub login or jq needed.
  metadata=$(curl --fail --silent --show-error --location \
    https://github.com/shamaazi/machines/releases/download/latest/images.json)
  checksum=$(printf '%s' "$metadata" | plutil -extract "$role.sha256" raw -o - -)
  [[ "$checksum" =~ ^[a-f0-9]{64}$ ]]
}
pull_image() {
  # Resume large downloads and verify cached bytes against the release metadata.
  # Content keys prevent a replaced release from reusing stale files or images.
  download="$store/images/$checksum"
  mkdir -p "$download"
  archive="$download/nixos-$role-aarch64.oci.tar.gz"
  if ! { test -f "$archive" && printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 --check; }; then
    curl --fail --location --retry 5 --retry-all-errors --continue-at - --output "$archive.download" \
      "https://github.com/shamaazi/machines/releases/download/latest/nixos-$role-aarch64.oci.tar.gz"
    printf '%s  %s\n' "$checksum" "$archive.download" | shasum -a 256 --check
    mv "$archive.download" "$archive"
  fi
  # Apple imports an uncompressed OCI archive; retain only the compressed cache.
  expanded="$download/nixos-$role.oci.tar"
  gzip -dc "$archive" > "$expanded"
  "$cli" image load --input "$expanded"
  "$cli" image tag "nixos-$role:local" "nixos-$role:$checksum"
  unlink "$expanded"
}
up() {
    setup
    if ! "$cli" machine inspect "$name" >/dev/null 2>&1; then
      load_release
      published="nixos-$role:$checksum"
      if [ "$role" = dev ]; then image=${MACHINES_DEV_IMAGE:-$published}; else image=${MACHINES_TARGET_IMAGE:-$published}; fi
      if [ "$role" = dev ] && [ "$image" = "$published" ] && [ "$username" != developer ]; then
        echo 'The published dev image uses the developer account. Set MACHINES_USER=developer.' >&2
        exit 1
      fi
      if ! "$cli" image inspect "$image" >/dev/null 2>&1; then
        if [ "$image" != "$published" ]; then
          echo "Import custom image $image first." >&2
          exit 1
        fi
        pull_image
      fi
      # Match the NixOS image's accounts; keep repositories on the Linux disk.
      if [ "$role" = dev ]; then machine_uid=1000; machine_gid=100; else machine_uid=0; machine_gid=0; fi
      # Apple's account setup can race NixOS activation on first boot. The
      # readiness pass resumes the guest after its account files have settled.
      env -u SSH_AUTH_SOCK "$cli" machine create --name "$name" --home-mount none \
        --cpus "$cpus" --memory "$memory" --user "$username" --uid "$machine_uid" --gid "$machine_gid" "$image" || echo 'Checking guest readiness after boot.'
    fi
    # machine run also resumes a stopped machine. Existing disks/configurations survive.
    # The readiness loop runs inside the guest.
    # shellcheck disable=SC2016
    guest 'set -e; for attempt in $(seq 1 60); do systemctl is-active --quiet multi-user.target 2>/dev/null && exit 0; sleep 1; done; exit 1'
    mkdir -p "$keys"
    chmod 700 "$keys"
    test -f "$keys/id_ed25519" || ssh-keygen -q -t ed25519 -N '' -f "$keys/id_ed25519"
    authorize < "$keys/id_ed25519.pub"
    host_address=$(address)
    # Read the host key over Apple's local transport rather than trusting the network.
    { printf '[%s]:%s ' "$host_address" "$port"; guest 'cat /etc/ssh/ssh_host_ed25519_key.pub'; } > "$keys/known_hosts"
    ssh_config "$host_address" "$username" "$port" "$keys/id_ed25519" "$keys/known_hosts" > "$keys/config"
    chmod 600 "$keys/config" "$keys/known_hosts"
    ssh -n -F "$keys/config" "$role" 'hostname; uname -m'
    printf 'SSH: ssh -F "%s/config" %s\n' "$keys" "$role"
}
# Also serve as machine's shared functions without running interactive onboarding.
if [[ ${BASH_SOURCE[0]:-$0} == "$0" ]]; then
  if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
    echo 'Machines requires an Apple Silicon Mac.' >&2
    exit 1
  fi
  macos_version=$(sw_vers -productVersion)
  if [ "${macos_version%%.*}" -lt 26 ]; then
    echo 'Machines requires macOS 26 or newer.' >&2
    exit 1
  fi
  role=dev
  name=${MACHINES_DEV_NAME:-dev-build}
  username=${MACHINES_USER:-developer}
  port=2223
  # Leave headroom for development services alongside bounded parallel Nix builds.
  cpus=${MACHINES_DEV_CPUS:-8}
  memory=${MACHINES_DEV_MEMORY:-10G}
  keys="$store/ssh/dev"
  [[ "$name" =~ ^[a-zA-Z0-9_-]+$ && "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] || exit 2
  # With curl | bash, provisioning must not consume script input; SSH uses the TTY.
  up </dev/null
  exec ssh -t -F "$keys/config" dev </dev/tty
fi
