# Machines

Run on an Apple Silicon Mac:

```sh
curl -fsSL https://raw.githubusercontent.com/shamaazi/machines/main/bootstrap.sh | bash
```

Starts a persistent NixOS VM using Lima's upstream community image, applies our
Nix configuration inside it, and opens a shell. Includes git, gh and devenv.
No Mac checkout, host Nix or GitHub login is required. Rerunning reconnects.
Editors and Codex connect to SSH host `lima-dev`; devenv's `.localhost` URLs work
through automatic port forwarding. Defaults: 8 CPUs, 10 GiB RAM, 80 GiB disk.
State stays in `~/.local/share/machines`. Deployment targets are separate.
