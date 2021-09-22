#!/bin/sh
# -*- mode: sh -*-

SCRIPT_NAME="${0##*/}"
SCRIPT_RPATH="${0%$SCRIPT_NAME}"
SCRIPT_PATH=`cd "${SCRIPT_RPATH:-.}" && pwd`

SYSH_ENTROPY="/proc/sys/kernel/random/entropy_avail"
SYSH_ENTROPY_BASE=3000

cat_entropy()
{
    if [ -z "$SYSH_ENTROPY" ] || [ ! -r "$SYSH_ENTROPY" ]; then
        echo >&2 "no entropy file ($SYSH_ENTROPY)"
        return 1
    fi

    cat_entropy=`cat "$SYSH_ENTROPY"`
    echo "$cat_entropy"

    if [ "$cat_entropy" -le "$SYSH_ENTROPY_BASE" ]; then
        echo >&2 "not enough, < $SYSH_ENTROPY_BASE"
    fi
}


### main
case "$SCRIPT_NAME" in
    cat_*)
        "$SCRIPT_NAME" "$@"
        ;;
esac
