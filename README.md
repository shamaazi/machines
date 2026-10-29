# Machines

Run on an Apple Silicon Mac:

```sh
curl -fsSL https://raw.githubusercontent.com/shamaazi/machines/main/bootstrap.sh | bash
```

Starts a persistent NixOS VM using Lima's upstream community image, applies our
Nix configuration inside it, and opens a shell. Includes git, gh and devenv.
One-time setup; no Mac checkout, host Nix or GitHub login is required.
The VM starts at login. In a new Mac terminal, use `limactl shell dev` to connect,
`limactl stop dev` to stop it, and `limactl start dev` to start it again.
Editors and Codex connect to SSH host `lima-dev`; devenv's `.localhost` URLs work
through automatic port forwarding. New VMs use all CPU cores and the laptop's
RAM minus 8 GiB reserved for macOS, with an 80 GiB disk.
Lima state stays in `~/.lima`. Deployment targets are separate.
Disable login startup with `limactl autostart disable dev`.
