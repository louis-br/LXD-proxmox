FROM docker.io/debian:bullseye-slim
#ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install --yes wget
COPY config/pve-install-repo.list /etc/apt/sources.list.d/pve-install-repo.list
RUN wget https://enterprise.proxmox.com/debian/proxmox-release-bullseye.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bullseye.gpg
RUN apt-get update && apt-get upgrade --no-install-recommends --yes
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --yes postfix
RUN apt-get install --no-install-recommends --yes open-iscsi
#RUN mkdir --parents /var/lib/dhcp
#RUN apt-get install --no-install-recommends --yes -o Dpkg::Options::="--pre-invoke=cat /proc/\$PPID/cmdline; echo \$@ \$DPKG_HOOK_ACTION" ifupdown2
#o Dpkg::Pre-Install-Pkgs::="ls /var/lib/dpkg/info/ifupdown2.* || true" 
RUN apt-get install --no-install-recommends --download-only --yes ifupdown2
RUN apt-get install --no-install-recommends --yes -o Dpkg::Options::="--pre-invoke=rm -f /var/lib/dpkg/info/ifupdown2.postinst || true" ifupdown2
RUN apt-get install --no-install-recommends --download-only --yes pve-manager
RUN apt-get install --no-install-recommends --yes -o Dpkg::Options::="--pre-invoke=rm -f /var/lib/dpkg/info/pve-manager.postinst || true" pve-manager
RUN apt-get install --no-install-recommends --download-only --yes proxmox-ve
RUN apt-get install --no-install-recommends --yes -o Dpkg::Options::="--pre-invoke=rm -f /var/lib/dpkg/info/initramfs-tools.postinst /var/lib/dpkg/info/pve-kernel-5.15.83-1-pve.postinst || true" proxmox-ve
RUN apt-get install --no-install-recommends --yes --reinstall systemd init

RUN echo "root:root" | chpasswd