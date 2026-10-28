# Machines

Run on an Apple Silicon Mac with macOS 26:

```sh
curl -fsSL https://raw.githubusercontent.com/shamaazi/machines/main/bootstrap.sh | bash
```

Sets up a persistent dev VM from the latest release and opens its SSH shell.
Includes git, gh and devenv; defaults to 8 CPUs and 10 GiB RAM.
No local checkout, host Nix or GitHub login is required. Rerunning reconnects.
Machine state stays in `~/.local/share/machines`; deployment targets are separate.
