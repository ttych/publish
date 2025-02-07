#!/bin/sh

echo2()
{
    echo >&2 "$@"
}

which_dnf()
{
    which dnf 2>/dev/null >/dev/null
}

KERNEL_VERSION_RUNNING=`uname -r`
KERNAL_VERSION_LATEST=$(dnf repoquery --installonly --latest-limit=1 --qf '%{EVR}.${ARCH}')

if ! which_dnf; then
    echo2 '# not a dnf environment'
    exit 1
fi

[ "$KERNEL_VERSION_RUNNING" = "$KERNAL_VERSION_LATEST" ]
