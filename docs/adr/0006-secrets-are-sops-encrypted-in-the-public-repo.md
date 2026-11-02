# Secrets are sops-encrypted in the public repo

Status: accepted

Secrets were kept by hand in out-of-repo files, so a rebuilt host lost them and
nothing recorded what they were. They now live in this repo under `secrets/`,
encrypted with sops-nix and decrypted at activation to a runtime path outside
the Nix store. Each host decrypts with an age key derived from its SSH host key.
Recipients are per host, so a host reads only `secrets/<host>.yaml` and
`secrets/shared.yaml`. The user is a recipient of everything through a dedicated
age key held in Bitwarden and fetched on demand, so editing and recovery depend
on no machine's disk surviving.

This amends [ADR-0002](0002-issues-live-in-a-separate-private-repo.md): the
public tree now holds ciphertext, so what it promises is that nothing is a
plaintext credential.

Only secrets that can be rotated belong here. Git history keeps every version of
every encrypted file for good, so if a recipient key ever leaks, every past
version it could read is readable, and the only response is rotating the secrets
themselves. Age's X25519 is not post-quantum either, and anyone can archive the
ciphertext today. Both are acceptable for a key that can be replaced, not for one
that must hold for a decade, such as a backup encryption password.

## Considered options

- **agenix.** Smaller, with one file per secret. Fits a host running one service
  from one whole env file. Rejected because the secrets here are separate values
  combined into files, such as a wifi profile's identity and password, and sops
  templates build those without one encrypted file per format.
- **A private secrets repo as a flake input.** Publishes nothing, but every build
  needs GitHub auth, the same bootstrap problem ADR-0002 rejected.
- **Staying out of the repo.** Publishes nothing, and leaves every secret to be
  recreated by hand on a rebuild.
- **A dedicated age key per host.** One more file to hand-provision before the
  first rebuild, where the SSH host key already exists.
- **The sops-nix home-manager module.** Needs a user-level key on disk on every
  host, since the Bitwarden key can't be fetched unattended. User keys are
  system-layer secrets owned by the user instead.

## Consequences

- A host's recipient key is only as safe as its disk: whoever holds a host's SSH
  host key can read every secret that host is a recipient of.
- Decrypted keys in `/run/secrets` are readable by anything running as the user.
  They reach programs as files, or through wrappers and direnv, never by a global
  export, which stops accidental inheritance but not a process that goes looking.
  High-value keys can later move to on-demand `sops exec-env`, which leaves nothing
  decrypted unless a command is running.
- sops leaves key names, file names and recipients readable, which is a profile.
- A new host must become a recipient before its first rebuild that needs a secret.
