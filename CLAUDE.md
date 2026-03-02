# SFTP Server -- Development Notes

Hardened SFTP-only Docker container. Key-only authentication, chroot jails.

## File Structure

- `Dockerfile` -- Container build (debian:trixie-slim + openssh-server, OpenSSH 10.0)
- `files/sshd_config` -- OpenSSH server configuration (hardened)
- `files/entrypoint` -- Container entrypoint (user creation, key generation, sshd)
- `files/create-sftp-user` -- User creation script (called per user line)
- `tests/run` -- shunit2 test suite (requires Docker, run with sudo)
- `tests/files/users.conf` -- Test fixture for user config parsing

## Running Tests

```bash
git submodule update --init
sudo tests/run build verbose cleanup
```

Arguments: `build|nobuild`, `quiet|verbose`, `cleanup|nocleanup`

## Key Design Decisions

- Password field in user config is parsed but ignored (backward compat with `:e:` format)
- Only ed25519 host keys (no RSA)
- Users get `/usr/sbin/nologin` shell as defense-in-depth
- Host keys regenerated with WARNING log if not mounted
- Custom scripts in `/etc/sftp.d/` run between user creation and sshd start
- Forked from atmoz/sftp (abandoned upstream, last commit 2018)
