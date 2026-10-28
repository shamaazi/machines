# Machines

This repository provisions generic NixOS development/build machines and deployment targets. Keep application code, source snapshots, application services, databases and application deployment policy in their owning repositories.

Mac onboarding and lifecycle commands use built-in macOS tools and Apple Container only; never require installing Nix or devenv on the host. Nix builds and application tooling run inside Linux. Contributors may use `devenv shell` and native tasks for repository checks. Keep machine-specific names, credentials and state in ignored local configuration. Never commit private keys or secrets. Public NixOS modules consume their caller's Nixpkgs; do not pin a second application toolchain inside them.

Do not create or modify AWS resources without an explicit instruction. Validate Apple Container lifecycle changes on local disposable machines where practical. Never delete or reinstall a pre-existing user machine to test provisioning. Stop and remove disposable machines created for the current validation when finished. Preserve persistent disks and existing deployments when adopting machines.
