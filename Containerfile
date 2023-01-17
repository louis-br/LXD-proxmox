FROM docker.io/debian:bullseye
RUN apt-get update && apt-get install --yes init

#ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install --yes wget
COPY config/pve-install-repo.list /etc/apt/sources.list.d/pve-install-repo.list
RUN wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
RUN apt-get update && apt-get upgrade --no-install-recommends --yes
RUN apt-get install --yes locales
RUN apt-get install --yes ifupdown
RUN apt-get install --yes nano

RUN apt-get install --no-install-recommends --download-only --yes proxmox-ve postfix open-iscsi

#COPY config/net /etc/network/interfaces.d/net

RUN echo "nameserver 10.1.1.1" >> /etc/resolv.conf

RUN echo "root:root" | chpasswd