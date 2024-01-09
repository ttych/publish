#!/bin/sh

SCRIPT_NAME="${0##*/}"
SCRIPT_RPATH="${0%$SCRIPT_NAME}"
SCRIPT_PATH=`cd "${SCRIPT_RPATH:-.}" && pwd`

BPOOL_NAME="${BPOOL_NAME:-bpool}"
RPOOL_NAME="${RPOOL_NAME:-rpool}"

PART_EFI_ID=1
PART_BIOS_ID=4
PART_BPOOL_ID=2
PART_RPOOL_ID=3
# PART_SWAP_ID=

MNT="${MNT:-/mnt}"
HOSTNAME="${HOSTNAME:-server.local}"
OS_CODENAME="$(lsb_release -c -s)"

PKG_TOOLS="openssh-server vim emacs-nox"
PKG_REQ="debootstrap gdisk zfsutils-linux mdadm"

DEV_D=/dev
DEV_DISK_ID_D=$DEV_D/disk/by-id

UBUNTU_UUID=$(dd if=/dev/urandom bs=1 count=100 2>/dev/null | tr -dc 'a-z0-9' | cut -c-6)
UBUNTU_CODENAME=`lsb_release -c -s 2>/dev/null`


TRUE()
{
    return 0
}

FALSE()
{
    return 1
}

echo2()
{
    echo >&2 "$@"
}

log()
{
    log__context=
    if [ $# -gt 1 ]; then
        log__context="[$1] "
        shift
    fi

    echo2 "$log__context""$@"
}

timer()
{
    timer="${1:60}"

    while [ $1 -gt 0 ]; do
        sleep 1
        timer=$(($timer - 1))
    done
}


### apt

apt_update()
{
    apt -q -y update
}

apt_install()
{
    apt_update && \
        apt -q -y install "$@"
}

apt_source_add()
{
    apt_source_add__file="${2:-/etc/apt/sources.list}"

    grep -q "$1" "$apt_source_add__file" || \
        echo "$1" >> "$apt_source_add__file"
}

apt_purge()
{
    apt purge --yes "$@"
}

apt_dist_upgrade()
{
    apt -y dist-upgrade
}


### packages

pkg_tools()
{
    apt_install $PKG_TOOLS || return 1
}

pkg_prereq()
{
    apt_install $PKG_REQ || return 1
    systemctl stop zed || return 1
}




### network

my_ip()
{
    my_ip=$(ip addr show scope global | grep inet | sed -e 's/^\s*inet\s*\([0-9./]*\)\s*.*$/\1/g' | head -n 1)
}

network_link()
{
    network_link=$(ip link show | awk '/^[0-9]+:/ {print $2}' | grep -v lo:)
    network_link="${network_link%%:*}"
    echo $network_link
}


### disk

disk_id_list()
{
    if [ $# -eq 0 ]; then
        set -- "$DEV_DISK_ID_D"/*
    fi

    for disk_id_list__d; do
        disk_id "$disk_id_list__d" || continue

        if ! $disk_id__part; then
            echo "$disk_id__id  ( $disk_id__dev )"
        fi
    done | sort
}

disk_id()
{
    disk_id__path=
    disk_id__mode=
    disk_id__hardlink=
    disk_id__owner=
    disk_id__group=
    disk_id__date=
    disk_id__id=
    disk_id__id_path=
    disk_id__dev=
    disk_id__dev_path=
    disk_id__part=

    [ -z "$1" ] && return 1

    case "$1" in
        /dev/*) disk_id__path="$1"
                ;;
        /*) log disk_id "expect $1 to be in /dev"
            return 1
            ;;
        *)  if [ -r "$DEV_DISK_ID_D/$1" ]; then
                disk_id__path="$DEV_DISK_ID_D/$1"
            fi
            ;;
    esac

    if [ -z "$disk_id__path" ]; then
        log disk_id "$1 is not a valid disk id"
        return 1
    fi

    disk_id__ll=`ls -l "$disk_id__path"`
    disk_id__tmp="$disk_id__ll"
    disk_id__mode="${disk_id__tmp%% *}"
    disk_id__tmp="${disk_id__tmp#$disk_id__mode }"
    disk_id__hardlink="${disk_id__tmp%% *}"
    disk_id__tmp="${disk_id__tmp#$disk_id__hardlink }"
    disk_id__owner="${disk_id__tmp%% *}"
    disk_id__tmp="${disk_id__tmp#$disk_id__owner }"
    disk_id__group="${disk_id__tmp%% *}"
    disk_id__tmp="${disk_id__tmp#$disk_id__group }"
    disk_id__date="${disk_id__tmp%% /*}"
    disk_id__tmp="${disk_id__tmp#$disk_id__date }"
    disk_id__id="${disk_id__tmp%% -> *}"
    disk_id__id="${disk_id__id##*/}"
    disk_id__id_path="${DEV_DISK_ID_D}/$disk_id__id"
    disk_id__dev="${disk_id__tmp##* -> }"
    disk_id__dev="${disk_id__dev##*/}"
    disk_id__dev_path="/dev/${disk_id__dev}"

    # case $disk_id__dev in
    #     *p[0-9]) disk_id__part=TRUE
    #              ;;
    #     *) disk_id__part=FALSE
    #        ;;
    # esac

    disk_id__part=FALSE
    if lsblk "$disk_id__dev_path" | grep -w "$disk_id__dev" | grep -q -w part; then
        disk_id__part=TRUE
    fi

    if [ ! -r "$disk_id__id_path" ]; then
        log disk "$1 is not a valid disk_id ($disk_id__id_path)"
        return 1
    fi

    if [ ! -b "$disk_id__dev_path" ]; then
        log disk "$1 is not pointing to a block device ($disk_id__dev_path)"
        return 1
    fi
}

disk_id_partitioned()
{
    disk_id "$1" || return 1
    $disk_id__part && return 0

    lsblk "$disk_id__dev_path" | grep -q -w part
}

disk_dev()
{
    disk_dev=
    disk_dev__path=

    [ -z "$1" ] && return 1

    case "$1" in
        /dev/*) disk_dev__path="$1"
                ;;
        /*) log disk_dev "expect $1 to be in /dev"
            return 1
            ;;
        *)  if [ -r "$DEV_D/$1" ]; then
                disk_dev__path="$DEV_D/$1"
            fi
            ;;
    esac

    if [ ! -b "$disk_dev__path" ]; then
        log disk_id "$1 is not a valid disk dev"
        return 1
    fi

    disk_dev="${disk_dev__path##*/}"
}

disk_wipe()
{
    disk_dev "$1" || return 1

    log disk_swipe "swapoff --all"
    swapoff --all || return 1

    wipefs -a "$disk_dev__path" || return 1
    blkdiscard -f "$disk_dev__path"
    sgdisk --zap-all "$disk_dev__path" || return 1
}

disk_format_root()
{
    disk_dev "$1" || return 1

    # EFI
    sgdisk     -n${PART_EFI_ID}:1M:+512M   -t${PART_EFI_ID}:EF00 "$disk_dev__path"
    # BIOS
    # sgdisk -a1 -n${PART_BIOS_ID}:24K:+1000K -t${PART_BIOS_ID}:EF02 "$disk_dev__path"
    # boot pool
    sgdisk     -n${PART_BPOOL_ID}:0:+2G      -t${PART_BPOOL_ID}:BE00 "$disk_dev__path"
    # root pool
    sgdisk     -n${PART_RPOOL_ID}:0:0        -t${PART_RPOOL_ID}:BF00 "$disk_dev__path"
}


### zfs

zfs_create_rpool()
{
    zfs_create_rpool__devs=
    case $# in
        1) zfs_create_rpool__devs="${1}-part${PART_RPOOL_ID}"
           ;;
        2) zfs_create_rpool__devs="mirror ${1}-part${PART_RPOOL_ID} ${2}-part${PART_RPOOL_ID}"
           ;;
        *) log zfs_create_bpool "does not support more than 2 parts"
           return 1
           ;;
    esac

    log zfs_create_rpool "zpool create [...] $RPOOL_NAME $zfs_create_rpool__devs"
    zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -O acltype=posixacl -O xattr=sa -O dnodesize=auto \
    -O compression=lz4 \
    -O normalization=formD \
    -O atime=off -O relatime=off \
    -O canmount=off -O mountpoint=/ -R "$MNT" \
    "$RPOOL_NAME" $zfs_create_rpool__devs
}

zfs_create_bpool()
{
    zfs_create_bpool__devs=
    case $# in
        1) zfs_create_bpool__devs="${1}-part${PART_BPOOL_ID}"
           ;;
        2) zfs_create_bpool__devs="mirror ${1}-part${PART_BPOOL_ID} ${2}-part${PART_BPOOL_ID}"
           ;;
        *) log zfs_create_bpool "does not support more than 2 parts"
           return 1
           ;;
    esac

    log zfs_create_rpool "zpool create [...] $BPOOL_NAME $zfs_create_bpool__devs"
    zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -o cachefile=/etc/zfs/zpool.cache \
    -o compatibility=grub2 \
    -o feature@livelist=enabled \
    -o feature@zpool_checkpoint=enabled \
    -O devices=off \
    -O acltype=posixacl -O xattr=sa \
    -O compression=lz4 \
    -O normalization=formD \
    -O atime=off -O relatime=off \
    -O canmount=off -O mountpoint=/boot -R "$MNT" \
    "$BPOOL_NAME" $zfs_create_bpool__devs
}

zfs_pool_clean_all()
{
    log zfs_pool_clean_all "import $BPOOL_NAME for destroy"
    zpool import -N -f "$BPOOL_NAME"
    log zfs_pool_clean_all "try to destroy $BPOOL_NAME"
    zpool destroy -f "$BPOOL_NAME"

    log zfs_pool_clean_all "import $RPOOL_NAME for destroy"
    zpool import -N -f "$RPOOL_NAME"
    log zfs_pool_clean_all "try to destroy $RPOOL_NAME"
    zpool destroy -f "$RPOOL_NAME"
}

zfs_have_bpool()
{
    zfs list "$BPOOL_NAME" >/dev/null && return 0

    zfs import -R "$MNT" -f "$BPOOL_NAME"
}

zfs_have_rpool()
{
    zfs list "$RPOOL_NAME" >/dev/null && return 0

    zfs import -R "$MNT" -f "$RPOOL_NAME"
}

zfs_dataset()
{
    zfs_dataset__name="$1"; shift

    zfs list "$zfs_dataset__name" 2>/dev/null >/dev/null && return 0

    zfs create "$@" "$zfs_dataset__name"
}

zfs_sys_datasets()
{
    zfs_dataset rpool/ROOT -o canmount=off -o mountpoint=none || return 1
    zfs_dataset bpool/BOOT -o canmount=off -o mountpoint=none || return 1

    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID \
                -o mountpoint=/ \
                -o com.ubuntu.zsys:bootfs=yes \
                -o com.ubuntu.zsys:last-used=$(date +%s)
    zfs_dataset bpool/BOOT/ubuntu_$UBUNTU_ID \
                -o mountpoint=/boot

    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/usr \
                -o com.ubuntu.zsys:bootfs=no -o canmount=off

    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var \
                -o com.ubuntu.zsys:bootfs=no -o canmount=off
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/lib
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/log
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/spool
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/cache
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/lib/nfs
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/lib/apt
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/lib/dpkg
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/lib/AccountsService
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/lib/NetworkManager
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/lib/docker
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/mail
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/snap
    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/www

    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/var/tmp
    chmod 1777 "$MNT"/var/tmp

    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/usr/local

    zfs_dataset rpool/DATA \
                -o canmount=off -o mountpoint=/
    zfs_dataset rpool/DATA/home \
                -o com.ubuntu.zsys:bootfs-datasets=rpool/ROOT/ubuntu_$UBUNTU_ID \
                -o canmount=on -o mountpoint=/home
    zfs_dataset rpool/DATA/home/root \
                -o mountpoint=/root
    zfs_dataset rpool/DATA/home/admin

    chmod 0700 "$MNT"/root
    chmod 0700 "$MNT"/home/admin

    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/service \
                -o com.ubuntu.zsys:bootfs=no

    zfs_dataset bpool/grub \
                -o com.ubuntu.zsys:bootfs=no

    zfs_dataset rpool/ROOT/ubuntu_$UBUNTU_ID/tmp \
                -o com.ubuntu.zsys:bootfs=no
    chmod 1777 "$MNT"/tmp
}

zfs_cache_copy_mnt()
{
    mkdir -p "$MNT"/etc/zfs
    cp /etc/zfs/zpool.cache "$MNT"/etc/zfs/
}


### sys

sys_run_tmpfs()
{
    mkdir -p "$MNT"/run
    if ! (mount -l -t tmpfs | grep -q -w "$MNT"/run); then
        mount -t tmpfs tmpfs "$MNT"/run
    fi
    mkdir -p "$MNT"/run/lock
}

sys_install_minimal()
{
    [ -r "$MNT/etc/debian_version" ] && return 0
    debootstrap "$UBUNTU_CODENAME" "$MNT"
}

sys_hostname_configure()
{
    hostname "$UBUNTU_HOSTNAME"
    hostname > "$MNT"/etc/hostname
    cat <<EOF > "$MNT"/etc/hosts
127.0.0.1  localhost ${UBUNTU_HOSTNAME%%.*} $UBUNTU_HOSTNAME
::1        localhost ip6-localhost ip6-loopback
ff02::1    ip6-allnodes
ff02::2    ip6-allrouters

127.0.1.1  ${UBUNTU_HOSTNAME%%.*} $UBUNTU_HOSTNAME
EOF
}

sys_network_configure()
{
    mkdir -p "$MNT"/etc/netplan
    cat <<EOF > "$MNT"/etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    $(network_link):
      dhcp4: true
EOF
}

sys_apt_sources()
{
    apt_source_add "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_CODENAME} main restricted universe multivers" "$MNT"/etc/apt/sources.list
    apt_source_add "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_CODENAME}-updates main restricted universe multiverse" "$MNT"/etc/apt/sources.list
    apt_source_add "deb http://archive.ubuntu.com/ubuntu ${UBUNTU_CODENAME}-backports main restricted universe multiverse" "$MNT"/etc/apt/sources.list
    apt_source_add "deb http://security.ubuntu.com/ubuntu ${UBUNTU_CODENAME}-security main restricted universe multiverse" "$MNT"/etc/apt/sources.list
}

sys_fs_loop()
{
    mount --make-private --rbind /dev  "$MNT"/dev
    mount --make-private --rbind /proc "$MNT"/proc
    mount --make-private --rbind /sys  "$MNT"/sys
}

sys_installer_copy()
{
    cp -f "$0" "$MNT"/root
    if [ -r "zubuntu.env" ]; then
        cp -f zubuntu.env "$MNT"/root
    fi
}


sys_install_chroot()
{
    chroot "$MNT" /usr/bin/env UBUNTU_ID=$UBUNTU_ID bash --login
}

sys_reconfigure()
{
    dpkg-reconfigure locales tzdata keyboard-configuration console-setup
}

sys_efi_configure()
{
    apt_install dosfstools

    sys_efi_configure__first=
    for sys_efi_configure__d in $ZUBUNTU_DISKS; do
        mkdosfs -F 32 -s 1 -n EFI ${sys_efi_configure__d}-part1
        [ -z "$sys_efi_configure__first" ] && sys_efi_configure__first="$sys_efi_configure__d"
    done

    mkdir -p /boot/efi
    echo /dev/disk/by-uuid/$(blkid -s UUID -o value ${sys_efi_configure__first}-part1) \
         /boot/efi vfat defaults 0 0 >> /etc/fstab
    mount /boot/efi
}

sys_grub_configure()
{
    apt_install \
        grub-efi-amd64 grub-efi-amd64-signed linux-image-generic shim-signed zfs-initramfs zsys || return 1

    apt_purge os-prober || return 1
}

sys_grub_install()
{
    [ "$(grub-probe /boot)" = "zfs" ] || return 1

    update-initramfs -c -k all || return 1

    [ -r "/etc/default/grub.orig" ] || cp -f /etc/default/grub /etc/default/grub.orig

    cat <<EOF > /etc/default/grub
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_RECORDFAIL_TIMEOUT=5
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="init_on_alloc=0"
GRUB_CMDLINE_LINUX=""
GRUB_TERMINAL=console
EOF

    update-grub || return  1

    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --no-floppy || return 1

    # systemctl mask grub-initrd-fallback.service
}

sys_zfs_cache_fix()
{
    mkdir -p /etc/zfs/zfs-list.cache
    touch /etc/zfs/zfs-list.cache/"$BPOOL_NAME"
    touch /etc/zfs/zfs-list.cache/"$RPOOL_NAME"
    zed -F &
    sleep 5
    pkill zed
    sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/*
}

sys_fs_tmp()
{
    cp /usr/share/systemd/tmp.mount /etc/systemd/system/ || return 1
    systemctl enable tmp.mount || return 1
}

sys_group_system()
{
    addgroup --system lpadmin
    addgroup --system lxd
    addgroup --system sambashare
}

sys_sshd_configure()
{
    apt_install openssh-server || return 1
}

sys_log_disable_compression()
{
    for file in /etc/logrotate.d/* ; do
        if grep -Eq "(^|[^#y])compress" "$file" ; then
            sed -i -r "s/(^|[^#y])(compress)/\1#\2/" "$file"
        fi
    done
}




### user

user_disable_password()
{
    [ -z "$1" ] || return 1
    id "$1" >/dev/null || return 1

    sudo usermod -p '*' root
}

user_admin()
{
    user_admin="${ZUBUNTU_ADMIN:-admin}"
    user_admin_id="${ZUBUNTU_ADMIN_ID:-2001}"

    root_ds=$(zfs list -o name | awk '/ROOT\/ubuntu_/{print $1;exit}')
    zfs create -o com.ubuntu.zsys:bootfs-datasets=$root_ds \
        -o canmount=on -o mountpoint=/home/"$user_admin" \
        rpool/DATA/home/"$user_admin"

    useradd -p '*' -G adm,cdrom,dip,lpadmin,lxd,plugdev,sambashare,sudo "$user_admin"

    mkdir -p /home/"$user_admin"/.ssh
    chmod 0700 /home/"$user_admin"/.ssh

    cp -a /etc/skel/. /home/"$user_admin"
    chown -R "$user_admin":"$user_admin" /home/"$user_admin"

    cat <<EOF > /etc/sudoers.d/$user_admin
%admin ALL=(ALL) NOPASSWD: ALL
EOF
}




### do_list_disk

do_list_disk()
{
    disk_id_list "$@"
}




### do_zfs_pool

do_zfs_pool()
{
    log install "create zfs pool"

    pkg_prereq || return 1

    zfs_pool_clean_all

    do_zfs_pool__disk1="$1"
    do_zfs_pool__disk2="$2"
    do_zfs_pool__disk_paths=

    if [ -z "$do_zfs_pool__disk1" ]; then
        log zfs_pool "please specify at least 1 disk"
        return 1
    fi

    for do_zfs_pool__disk in "$do_zfs_pool__disk1" "$do_zfs_pool__disk2"; do
        [ -z "$do_zfs_pool__disk" ] && continue

        if ! disk_id "$do_zfs_pool__disk"; then
            log zfs_pool "$do_zfs_pool__disk is not a valid disk"
            return 1
        fi
        if disk_id_partitioned "$disk_id__id"; then
            log zfs_pool "$disk_id__id is already partioned !"
            log zfs_pool "destroy $disk_id__id partitions ? (y/n)"
            read do_zfs_pool__answer
            case $do_zfs_pool__answer in
                [Yy]|[Yy][Ee][Ss]) ;;
                *) log zfs_pool "abort work on $disk_id__id"
                   return 1;;
            esac

            if ! disk_wipe "$disk_id__dev_path"; then
                log zfs_pool "aborting since disk_wipe on $disk_id__id ($disk_id__dev) failed !"
                return 1
            fi
        fi

        if ! disk_format_root "$disk_id__id_path"; then
            log zfs_pool "aborting since disk_format_root on $disk_id__id ($disk_id__dev) failed !"
            return 1
        fi

        do_zfs_pool__disk_paths="${do_zfs_pool__disk_paths} $disk_id__id_path"
    done

    partprobe

    if ! zfs_create_bpool $do_zfs_pool__disk_paths; then
        log zfs_pool "error while creating bpool"
        return 1
    fi
    if ! zfs_create_rpool $do_zfs_pool__disk_paths; then
        log zfs_pool "error while creating rpool"
        return 1
    fi

    echo export ZUBUNTU_DISKS=\"$do_zfs_pool__disk_paths\" >>  zubuntu.env
}




### do_install

do_install()
{
    log install "start install"

    pkg_prereq || return 1

    if [ -z "$UBUNTU_ID" ]; then
        log install "please define env var UBUNTU_ID, export UBUNTU_ID=001"
        return 1
    fi
    if [ -z "$UBUNTU_HOSTNAME" ]; then
        log install "please define env var UBUNTU_HOSTNAME, export UBUNTU_HOSTNAME=zubuntu.local"
        return 1
    fi

    if ! zfs_have_bpool; then
        log install "cannot use zfs pool for bpool ($BPOOL_NAME)"
        return 1
    fi
    if ! zfs_have_bpool; then
        log install "cannot use zfs pool for rpool ($RPOOL_NAME)"
        return 1
    fi

    zfs_sys_datasets || return 1

    sys_run_tmpfs || return 1

    sys_install_minimal || return 1

    zfs_cache_copy_mnt || return 1

    sys_hostname_configure || return 1
    sys_network_configure || return 1
    sys_apt_sources || return 1

    sys_fs_loop

    sys_installer_copy || return 1

    sys_install_chroot || return 1
}




### do_chroot_install

do_chroot_install()
{
    [ -r zubuntu.env ] && . ./zubuntu.env

    if [ -z "$ZUBUNTU_DISKS" ]; then
        log chroot_install "ZUBUNTU_DISKS is not set"
        return 1
    fi

    apt_update || return 1

    sys_reconfigure

    apt_install vim nano emacs-nox || return 1

    sys_efi_configure || return 1

    sys_grub_configure || return 1

    sys_fs_tmp || return 1

    sys_group_system || return 1

    sys_sshd_configure || return 1

    sys_grub_install || return 1

    sys_zfs_cache_fix || return 1

    exit
}


### do_first_boot

do_first_boot()
{
    dpkg-reconfigure grub-efi-amd64 || return 1

    user_admin || return 1

    apt_dist_upgrade || return 1

    apt_install ubuntu-standard || return 1

    # sys_log_disable_compression || return 1

    user_disable_password root
}




### main

usage()
{
    cat <<EOF
Usage is :
    $SCRIPT_NAME <action> <action_args>

With action in :
    h  | help
    ld | list-disk
    zp | zfs-pool <disk1> <disk2>
    i  | install
    ci | chroot-install
EOF
}

action="$1"
[ $# -gt 0 ] && shift
case "$action" in
    h|help|"")
        usage
        exit 0
        ;;
    ld|list-disk)
        do_list_disk "$@"
        ;;
    zp|zfs-pool)
        do_zfs_pool "$@"
        ;;
    i|install)
        do_install "$@"
        ;;
    ci|chroot-install)
        do_chroot_install "$@"
        ;;
    reboot)
        do_reboot "$@"
        ;;
    fb|first-boot)
        do_first_boot "$@"
        ;;
     *)
        usage
        exit 1
        ;;
esac
