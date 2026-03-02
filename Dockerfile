FROM debian:trixie-slim

LABEL org.opencontainers.image.title="sftp" \
      org.opencontainers.image.description="Hardened SFTP server (key-only auth)" \
      org.opencontainers.image.source="https://github.com/your-org/sftp"

RUN apt-get update && apt-get upgrade -y && \
    apt-get -y install openssh-server && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd && \
    rm -f /etc/ssh/ssh_host_*key*

COPY files/sshd_config /etc/ssh/sshd_config
COPY files/create-sftp-user /usr/local/bin/
COPY files/entrypoint /

EXPOSE 22

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD bash -c 'echo > /dev/tcp/localhost/22' || exit 1

ENTRYPOINT ["/entrypoint"]
