#!/bin/sh

SCRIPT_NAME="${0##*/}"
SCRIPT_RPATH="${0%$SCRIPT_NAME}"
SCRIPT_PATH=`cd "${SCRIPT_RPATH:-.}" && pwd`

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


#########################################

ZFSBOOTMENU_URL="https://get.zfsbootmenu.org/efi"
ZFSBOOTMENU_PATH="EFI/ZBM"
ZFSBOOTMENU_FILEPATH="$ZFSBOOTMENU_PATH/VMLINUZ.EFI"
ZFSBOOTMENU_BACKUP_FILEPATH="$ZFSBOOTMENU_PATH/VMLINUZ-BACKUP.EFI"

zfsbootmenu_check_device()
{
    lsblk --noheadings --pairs --paths --output NAME,FSTYPE,TYPE,MOUNTPOINTS "$1" | zfsbootmenu_check_device_pipe "$1"
}

zfsbootmenu_check_device_pipe()
{
    zfsbootmenu_check_device__valid=FALSE
    while read line ; do
        eval $line

        [ -z "$NAME" ] && continue

        if [ "$NAME" = "$1" ]; then
            if [ "$FSTYPE" = "vfat" ]; then
                zfsbootmenu_check_device__valid=TRUE
            fi
        fi

        if [ "$NAME" != "$1" ]; then
            echo2 "#!> This device $1 contains $TYPE like $NAME ($FSTYPE)"
            zfsbootmenu_check_device__valid=FALSE
        fi
    done

    $zfsbootmenu_check_device__valid
}

zfsbootmenu_get_mountpoint()
{
    lsblk --noheadings --output  MOUNTPOINTS "$1"
}

zfsbootmenu_usage()
{
    cat <<EOF
# > $0 </dev/disk_device_part_x>
EOF
}

zfsbootmenu()
{
    if [ $# -ne 1 ] || [ -z "$1" ]; then
        zfsbootmenu_usage
        return 1
    fi

    zfsbootmenu__device="$1"

    if ! zfsbootmenu_check_device "$zfsbootmenu__device"; then
       echo2 "#!> $zfsbootmenu__device is not a valid device"
       echo2
       zfsbootmenu_usage
       return 1
    fi

    zfsbootmenu__unmount_after=FALSE
    zfsbootmenu__mountpoint=$(zfsbootmenu_get_mountpoint "$1")
    if [ -z "$zfsbootmenu__mountpoint" ]; then
        zfsbootmenu__mountpoint="/mnt/zfsbootmenu"
        zfsbootmenu__unmount_after=TRUE
        mkdir -p "$zfsbootmenu__mountpoint" &&
            mount "$zfsbootmenu__device" "$zfsbootmenu__mountpoint" || {
                echo2 "#!> cannot mount $zfsbootmenu__device to $zfsbootmenu__mountpoint"
                return 1
            }
    fi

    mkdir -p "$zfsbootmenu__mountpoint/$ZFSBOOTMENU_PATH"
    [ -r "$zfsbootmenu__mountpoint/$ZFSBOOTMENU_FILEPATH" ] &&
        cp -f "$zfsbootmenu__mountpoint/$ZFSBOOTMENU_FILEPATH" "$zfsbootmenu__mountpoint/$ZFSBOOTMENU_BACKUP_FILEPATH"
    curl -o "$zfsbootmenu__mountpoint/$ZFSBOOTMENU_FILEPATH" -L "$ZFSBOOTMENU_URL" || {
        echo2 "#!> failed to download from $ZFSBOOTMENU_URL, reverting"
        cp -f "$zfsbootmenu__mountpoint/$ZFSBOOTMENU_BACKUP_FILEPATH" "$zfsbootmenu__mountpoint/$ZFSBOOTMENU_FILEPATH"
        return 1
    }

    if $zfsbootmenu__unmount_after; then
        umount "$zfsbootmenu__mountpoint" || {
            echo2 "#!> cannot unmount $zfsbootmenu__mountpoint ($zfsbootmenu__device)"
            return 1
        }
    fi
}



######################################### main

zfsbootmenu "$@"
