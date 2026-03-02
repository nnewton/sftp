# SFTP Server

Hardened SFTP server in a Docker container, using OpenSSH with key-only
authentication and chroot jails.

## Features

- **Key-only authentication** -- passwords are disabled entirely
- **Chroot jails** -- each user is confined to their home directory
- **Hardened cryptography** -- modern ciphers, MACs, and key exchange only
- **No shell access** -- `ForceCommand internal-sftp` with `/usr/sbin/nologin`
- **Rate limiting** -- `MaxAuthTries`, `MaxStartups`, and `LoginGraceTime`
- **Health checks** -- built-in Docker `HEALTHCHECK`
- **Audit logging** -- `LogLevel VERBOSE` enabled by default

## Quick Start

### Prerequisites

- Docker
- An SSH key pair for each SFTP user

### 1. Generate host keys (recommended)

Generate persistent host keys to avoid MITM warnings on container recreation:

```bash
ssh-keygen -t ed25519 -f ssh_host_ed25519_key -N '' < /dev/null
```

### 2. Run the container

```bash
docker run -d \
    -v ./ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key:ro \
    -v ./user_key.pub:/home/uploader/.ssh/keys/id_ed25519.pub:ro \
    -v /host/upload:/home/uploader/upload \
    -p 2222:22 \
    your-org/sftp \
    uploader:::1001:upload
```

### 3. Connect

```bash
sftp -P 2222 -i ~/.ssh/user_key uploader@<host>
```

## User Configuration

Users are defined in the format: `user:pass:uid:gid:dirs`

| Field | Description | Required | Default |
|-------|-------------|----------|---------|
| user  | Username (POSIX, max 32 chars) | Yes | -- |
| pass  | *(Ignored -- passwords disabled)* | No | -- |
| uid   | User ID | No | Auto |
| gid   | Group ID | No | Auto |
| dirs  | Comma-separated directories to create | No | -- |

> **Note:** The password field is retained for format compatibility but is
> always ignored. Authentication is exclusively via SSH keys.

The `:e:` encrypted password marker is also accepted for format
compatibility and silently ignored.

### Configuration methods

Users can be configured via (in order of precedence):

1. **Command arguments:**
   ```bash
   docker run ... your-org/sftp user1:::1001:upload user2:::1002:upload
   ```
2. **Environment variable:**
   ```bash
   docker run -e "SFTP_USERS=user1:::1001:upload user2:::1002:upload" ...
   ```
3. **Config file:**
   ```bash
   docker run -v ./users.conf:/etc/sftp/users.conf:ro ...
   ```

Example `users.conf`:
```
uploader:::1001:upload
reviewer:::1002:review
```

### SSH keys

Mount each user's public key(s) into `/home/<user>/.ssh/keys/`:

```bash
-v /path/to/key.pub:/home/uploader/.ssh/keys/id_ed25519.pub:ro
```

All files in `.ssh/keys/` are concatenated into `authorized_keys` at
startup. A warning is logged if no keys are found for a user.

## Docker Compose Example

```yaml
services:
  sftp:
    image: your-org/sftp
    ports:
      - "2222:22"
    volumes:
      - ./ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key:ro
      - ./keys/uploader.pub:/home/uploader/.ssh/keys/id_ed25519.pub:ro
      - ./upload:/home/uploader/upload
    command: uploader:::1001:upload
```

## Host Keys

The container generates an ephemeral ed25519 host key on first start if
none is mounted. **For production use, always mount your own host key** to
provide a consistent server fingerprint:

```bash
-v ./ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key:ro
```

Generate a host key with:
```bash
ssh-keygen -t ed25519 -f ssh_host_ed25519_key -N '' < /dev/null
```

Without a persistent host key, clients will see MITM warnings whenever the
container is recreated.

## Custom Startup Scripts

Place executable scripts in `/etc/sftp.d/` to run them at container startup
(after user creation, before sshd starts):

```bash
-v ./my-script.sh:/etc/sftp.d/my-script.sh
```

Scripts must have the execute permission set (`chmod +x`). They run as root.

## Security Configuration

The following hardening is applied by default (see `files/sshd_config`):

| Setting | Value | Purpose |
|---------|-------|---------|
| `PasswordAuthentication` | `no` | Key-only access |
| `AuthenticationMethods` | `publickey` | Enforce single auth method |
| `MaxAuthTries` | `3` | Limit brute force |
| `MaxStartups` | `5:50:10` | Connection rate limiting |
| `LoginGraceTime` | `30` | Fast timeout for unauthenticated sessions |
| `ChrootDirectory` | `%h` | Jail users to home directory |
| `ForceCommand` | `internal-sftp` | No shell access |
| `KexAlgorithms` | `curve25519-sha256` variants | Modern key exchange only |
| `Ciphers` | `chacha20-poly1305`, `aes256-gcm`, `aes128-gcm` | AEAD ciphers only |
| `MACs` | `hmac-sha2-512-etm`, `hmac-sha2-256-etm` | Encrypt-then-MAC only |
| `LogLevel` | `VERBOSE` | Audit logging |
| `ClientAliveInterval` | `300` | Disconnect idle sessions (~10 min) |

## Building

```bash
docker build -t your-org/sftp .
```

## Testing

Tests use [shunit2](https://github.com/kward/shunit2) and require Docker:

```bash
git submodule update --init
sudo tests/run
```

Arguments: `build|nobuild`, `quiet|verbose`, `cleanup|nocleanup`

```bash
sudo tests/run build verbose cleanup
```

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
