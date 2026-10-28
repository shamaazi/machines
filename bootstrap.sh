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
  env -u SSH_AUTH_SOCK "$cli" system start --install-root "$store/installer/Payload" \
    --app-root "$store/state" --enable-kernel-install
}
guest() {
  # Apple's non-login transport lacks NixOS's normal shell PATH.
  "$cli" machine run -i -n "$name" --root -- "
    set -e
    export PATH=/nix/var/nix/profiles/system/sw/bin:/run/current-system/sw/bin
    $1
  "
}
address() {
  "$cli" machine inspect "$name" | plutil -extract 0.ipAddress raw -o - -
}
authorize() {
  guest '
    cat >> /etc/ssh/authorized_keys
    sort -u /etc/ssh/authorized_keys -o /etc/ssh/authorized_keys
    chmod 644 /etc/ssh/authorized_keys
  '
}
ssh_config() {
  local host_address=$1
  local host_user=$2
  local host_port=$3
  local identity=$4
  local hosts=$5
  cat <<EOF
Host $role
  HostName $host_address
  User $host_user
  Port $host_port
  IdentityFile "$identity"
  UserKnownHostsFile "$hosts"
  IdentitiesOnly yes
  StrictHostKeyChecking yes
  ForwardAgent no
EOF
}
load_release() {
  # Use macOS's parser so bootstrap needs no extra tools.
  checksum=$(
    curl --fail --silent --show-error --location \
      https://github.com/shamaazi/machines/releases/download/latest/images.json |
      plutil -extract "$role.sha256" raw -o - -
  )
  [[ "$checksum" =~ ^[a-f0-9]{64}$ ]]
}
pull_image() {
  # Content keys prevent a replaced release from reusing stale files or images.
  download="$store/images/$checksum"
  mkdir -p "$download"
  archive="$download/nixos-$role-aarch64.oci.tar.gz"
  if ! {
    test -f "$archive" &&
      printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 --check
  }; then
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
    if [ "$role" = dev ] && [ "$username" != developer ]; then
      echo 'The published dev image uses the developer account. Set MACHINES_USER=developer.' >&2
      exit 1
    fi
    load_release
    image="nixos-$role:$checksum"
    if ! "$cli" image inspect "$image" >/dev/null 2>&1; then
      pull_image
    fi
    # Match the NixOS image's accounts; keep repositories on the Linux disk.
    if [ "$role" = dev ]; then
      machine_uid=1000
      machine_gid=100
    else
      machine_uid=0
      machine_gid=0
    fi
    # Apple's account setup can race NixOS activation on first boot. The
    # readiness pass resumes the guest after its account files have settled.
    env -u SSH_AUTH_SOCK "$cli" machine create --name "$name" --home-mount none \
      --cpus "$cpus" --memory "$memory" --user "$username" \
      --uid "$machine_uid" --gid "$machine_gid" "$image" || echo 'Checking guest readiness after boot.'
  fi
  # machine run resumes a stopped guest without replacing its disk.
  # shellcheck disable=SC2016
  guest '
    for attempt in $(seq 1 60); do
      if systemctl is-active --quiet multi-user.target 2>/dev/null; then
        exit 0
      fi
      sleep 1
    done
    exit 1
  '
  install -d -m 700 "$keys"
  test -f "$keys/id_ed25519" || ssh-keygen -q -t ed25519 -N '' -f "$keys/id_ed25519"
  authorize < "$keys/id_ed25519.pub"
  host_address=$(address)
  # Read the host key over Apple's local transport rather than trusting the network.
  {
    printf '[%s]:%s ' "$host_address" "$port"
    guest 'cat /etc/ssh/ssh_host_ed25519_key.pub'
  } > "$keys/known_hosts"
  ssh_config "$host_address" "$username" "$port" "$keys/id_ed25519" "$keys/known_hosts" > "$keys/config"
  chmod 600 "$keys/config" "$keys/known_hosts"
  ssh -n -F "$keys/config" "$role" true
  printf 'SSH: ssh -F "%s/config" %s\n' "$keys" "$role"
}
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
  cpus=${MACHINES_DEV_CPUS:-8}
  memory=${MACHINES_DEV_MEMORY:-10G}
  keys="$store/ssh/dev"
  if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ && "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo 'Invalid machine name or username.' >&2
    exit 2
  fi
  # With curl | bash, provisioning must not consume script input; SSH uses the TTY.
  up </dev/null
  exec ssh -t -F "$keys/config" dev </dev/tty
fi
