FROM debian:stretch-slim

WORKDIR /opt

RUN apt-get update \
 && apt-get install -y curl vim awscli jq \
 && apt-get clean all \
 && rm -rf /var/lib/apt/lists/*

COPY etcd-backup.sh /opt
CMD ["/opt/etcd-backup.sh"]