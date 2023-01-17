#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

CONTAINER_NAME="proxmox"
LXC_PROCESS=""
CACHE=${CACHE:-true}

set -x

lxc_mount() {
    sudo lxc file mount "$1/" "temp/mount" &
    export LXC_PROCESS=$!
    sleep 1s
}

lxc_unmount() {
    setsid kill -s SIGINT "$LXC_PROCESS"
    wait "$LXC_PROCESS" || true
    LXC_PROCESS=""
}

rsync_rootfs() {
    local container="$1"
    local source="$2"
    local dest="$3"
    lxc_mount "$container"
    #sleep 1s
    sudo rsync  --archive \
                --no-times \
                --size-only \
                --executability \
                --acls \
                --xattrs \
                --specials \
                --delete \
                --force \
                --human-readable \
                --info=progress2 \
                "$source" "$dest"
                #--list-only \
#--ignore-times \
    #sleep 1s
    lxc_unmount
}

lxc_exec() {
    local name="$1"
    shift
    lxc exec "$name" -- sh -c "$*"
}

lxc_build() {
    export rootmnt="$1"
    lxc profile create "$name" || true
    cat ./proxmox-build.yml | envsubst
    cat ./proxmox-build.yml | envsubst | lxc profile edit "$name"
    tar --create --overwrite --gzip --file "temp/empty.tar.gz" --files-from /dev/null
    lxc image import "output/meta.tar" "temp/empty.tar.gz" --alias empty || true
    lxc init --profile default --profile "$name" --storage default empty "$name" || true
    rsync_rootfs "$name" "$rootmnt/." "temp/mount/"
    sudo lxc start "$name" || true
    #read
    lxc-wait --name="$name" --state="STOPPED|RUNNING"
    lxc_exec "$name" echo hello world
    lxc_exec "$name" DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --yes proxmox-ve postfix open-iscsi
    lxc file push config/net "$name/etc/network/interfaces.d/net"
    lxc stop "$name"
}

build() {
    local name="$1"
    mkdir --parents temp/mount/
    mkdir --parents output/

    sudo podman build --tag="$name" .

    sudo podman create --name="$name" "$name"
    local rootmnt=$(sudo podman mount "$name")
    
    tar --create --overwrite --absolute-names --file "output/meta.tar" --directory metadata $(ls --almost-all metadata)

    lxc_build "$rootmnt"

    echo "Exporting tar..."
    lxc_mount "$name"

    #Transform flags: apply transform to r = regular, S = NOT symbolic links, and h = hard links. 
    sudo tar --create --overwrite --absolute-names --file "output/$name.tar" --absolute-names --directory "temp/mount" --transform 'flags=rSh;s,^,rootfs/,' $(sudo ls --almost-all "temp/mount")
    sudo tar --concatenate --file="output/$name.tar" "output/meta.tar"
    
    lxc_unmount
    #lxc publish "$name" --force --alias "$name"
    #lxc image export "$name" "output/$name"

    rm -f "output/meta.tar"
    echo "Done"
}

clean() {
    local name="$1"
    sudo podman umount "$name" || true
    sudo podman container rm "$name" || true
}

#lxc_build() {
#    local name="$1"
#    lxc image delete "$name" || true
#    lxc image import "output/$name.tar" --alias "$name"
#    local digest=$(sudo podman image inspect --format '{{ .Digest }}' "$name")
#    if [[ "$digest" = $(<.sha-cache) ]]; then
#        echo "Image cached. "
#        return
#    fi
#    lxc profile create "$name" || true
#    lxc profile edit "$name" < ./proxmox-build.yml
#    lxc init --profile default --profile "$name" --storage default "$name" "$name"
#    lxc start "$name"
#    lxc-wait --name="$name" --state="STOPPED|RUNNING"
#    lxc_exec "$name" echo hello world
#    lxc_exec "$name" DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --yes proxmox-ve postfix open-iscsi
#    lxc stop "$name"
#    lxc publish "$name" --alias "$name"
#    sudo lxc image export "$name" "output/$name"
#    echo "$digest" > .sha-cache
#}
#
lxc_clean() {
    local name="$1"
    if [[ -n "$LXC_PROCESS" ]]; then
        setsid kill -s SIGINT "$LXC_PROCESS"
    fi
    lxc stop "$name" --quiet || true
    sleep 1s
    lxc-wait --name="$name" --state="STOPPED" || true
    if [[ "$CACHE" = false ]]; then
        lxc delete "$name" --force --quiet || true
    fi
    #lxc image delete "$name" || true
}

finish() {
    clean "$CONTAINER_NAME"
    lxc_clean "$CONTAINER_NAME"
}
trap finish EXIT

build "$CONTAINER_NAME"
clean "$CONTAINER_NAME"

#lxc_build "$CONTAINER_NAME"
#lxc_clean "$CONTAINER_NAME"