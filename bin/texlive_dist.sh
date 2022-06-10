#!/bin/sh

DEFAULT_TEXLIVE_DIR="$HOME/local/texlive"

OS_ARCH="$(uname -m)"
OS_NAME="$(uname -s | tr '[A-Z]' '[a-z]')"

TEXLIVE_TMPDIR="${TMPDIR:-/tmp}/texlive"
TEXLIVE_INSTALLER="install-tl"
TEXLIVE_INSTALLER_ARCHIVE="${TEXLIVE_INSTALLER}.zip"
TEXLIVE_INSTALLER_URL="${TEXLIVE_INSTALLER_URL:-http://mirror.ctan.org/systems/texlive/tlnet/$TEXLIVE_INSTALLER_ARCHIVE}"



###

texlive_env()
{
    TEXLIVE_DIR="${TEXLIVE_DIR:-$DEFAULT_TEXLIVE_DIR}"
    TEXLIVE_INSTALL_PREFIX="${TEXLIVE_INSTALL_PREFIX:-$TEXLIVE_DIR}"
    export TEXLIVE_INSTALL_PREFIX
    TEXLIVE_DIR="${TEXLIVE_INSTALL_PREFIX}"
    export TEXLIVE_DIR

    # TEXMFLOCAL /usr/local/texlive/texmf-local
    # export TEXLIVE_INSTALL_TEXMFLOCAL
    # TEXMFSYSCONFIG /usr/local/texlive/2022/texmf-config
    # export TEXLIVE_INSTALL_TEXMFSYSCONFIG
    # TEXMFSYSVAR /usr/local/texlive/2022/texmf-var
    # export TEXLIVE_INSTALL_TEXMFSYSVAR

    # TEXLIVE_VERSION="$(texlive_install_command --version | sed -ne 's/^.* version \(.*\)/\1/gp')"

    TEXMFHOME="${TEXMFHOME:-$HOME/.texmf}"
    TEXLIVE_INSTALL_TEXMFHOME="${TEXMFHOME:-$HOME/.texmf}"
    export TEXLIVE_INSTALL_TEXMFHOME
    TEXMFHOME="${TEXLIVE_INSTALL_TEXMFHOME}"
    export TEXMFHOME

    # TEXMFCONFIG ~/.texlive2022/texmf-config
    # export TEXLIVE_INSTALL_TEXMFCONFIG
    # TEXMFVAR ~/.texlive2022/texmf-var
    # export TEXLIVE_INSTALL_TEXMFVAR

    if [ -z "$TEXLIVE_DIST_DIR" ]; then
        TEXLIVE_DIST_BIN_DIR=
        for texlive_env__d in $(ls -1d "$TEXLIVE_DIR"/ "$TEXLIVE_DIR"/[0-9]*/ 2>/dev/null | sort -r)
        do
            texlive_env__d="${texlive_env__d%/}"
            [ -x "${texlive_env__d}/${TEXLIVE_INSTALLER}" ] || continue
            [ -d "${texlive_env__d}/bin" ] || continue
            [ -d "${texlive_env__d}/bin/${OS_ARCH}-${OS_NAME}" ] || continue
            # [ -x "$texlive_env__d/bin/${OS_ARCH}-${OS_NAME}/latex" ] || continue

            TEXLIVE_DIST_DIR="$texlive_env__d"
            TEXLIVE_DIST_BIN_DIR="${texlive_env__d}/bin/${OS_ARCH}-${OS_NAME}"
            export TEXLIVE_DIST_DIR TEXLIVE_DIST_BIN_DIR
            texlive_add_to_path "$TEXLIVE_DIST_BIN_DIR"
            break
        done
    fi
}

texlive_add_to_path()
{
    [ -n "$1" ] || return 1
    [ -d "$1" ] || return 1

    case "$PATH" in
        "*:$1:*"|"$1:*"|"*:$1")
            :
            ;;
        *)
            PATH="$1:$PATH"
            export PATH
            ;;
    esac
}

texlive_check_present()
{
    [ -n "$TEXLIVE_DIR" ] || return 1
    [ -d "$TEXLIVE_DIR" ] || return 1
    [ -n "$TEXLIVE_DIST_DIR" ] || return 1
    [ -d "$TEXLIVE_DIST_DIR" ] || return 1
    [ -x "$TEXLIVE_DIST_DIR/${TEXLIVE_INSTALLER}" ] || return 1
    [ -n "$TEXLIVE_DIST_BIN_DIR" ] || return 1
    [ -d "$TEXLIVE_DIST_BIN_DIR" ] || return 1

    return 0
}

texlive_check_installed()
{
    texlive_check_present || return 1

    [ -n "$TEXLIVE_DIST_BIN_DIR" ] || return 2
    [ -x "$TEXLIVE_DIST_BIN_DIR/tlmgr" ] || return 2
    [ -x "$TEXLIVE_DIST_BIN_DIR/latex" ] || return 2

    return 0
}

texlive_install_command()
{
    perl ./${TEXLIVE_INSTALLER} -no-gui -no-cls "$@"
}

texlive_install_dist_download()
{
    rm -Rf "${TEXLIVE_TMPDIR}" &&
        mkdir -p "${TEXLIVE_TMPDIR}" &&
        curl -s -S -L "$TEXLIVE_INSTALLER_URL" -o "$TEXLIVE_TMPDIR/$TEXLIVE_INSTALLER_ARCHIVE" &&
        unzip -q "$TEXLIVE_TMPDIR/$TEXLIVE_INSTALLER_ARCHIVE" -d "$TEXLIVE_TMPDIR"
}

texlive_install_dist_ext_build()
(
    cd "$TEXLIVE_TMPDIR/${TEXLIVE_INSTALLER_ARCHIVE%.zip}-$(date +%Y%m%d)" 2>/dev/null ||
        cd "$TEXLIVE_TMPDIR/${TEXLIVE_INSTALLER_ARCHIVE%.zip}-$(date +%Y%m)*" 2>/dev/null || {
            echo >&2 "Not able to change dir to: $TEXLIVE_TMPDIR/${TEXLIVE_INSTALLER_ARCHIVE%.zip}-$(date +%Y%m%d)"
            return 1
        }

    texlive_install_command -portable
)

texlive_install_dist_local()
{
    cd "$TEXLIVE_DIST_DIR" &&
        texlive_install_command -portable
}

texlive_install_dist_ext()
{
    texlive_install_dist_download &&
        texlive_install_dist_ext_build &&
        texlive_env &&
        texlive_test_dist
}

texlive_update_dist()
{
    :
    # FIXME: finalize update
    # texlive_update()
# {
#     texlive_status s || {
#         echo >&2 "TeXlive not installed !"
#         return 1
#     }

#     exit 1
# }
    # # sudo env PATH="$PATH" tlmgr update --self --all


    # FIXME: upgrade

# https://mirror.ctan.org/systems/texlive/tlnet/update-tlmgr-latest.sh
# sh update-tlmgr-latest.sh -- --upgrade
# https://tug.org/texlive/upgrade.html

# FIXME: tlmgr
# https://tex.stackexchange.com/questions/483613/unable-to-connect-via-tlmgr

# FIXME: sudo tlmgr update --list
# FIXME: sudo tlmgr update --all

# FIXME:
# https://tex.stackexchange.com/questions/27993/can-i-download-ctan-packages-from-the-command-line-ubuntu

}

texlive_display_info()
{
     for var in TEXLIVE_DIR TEXMFHOME TEXLIVE_DIST_DIR TEXLIVE_DIST_BIN_DIR; do
        eval value=\"\$$var\"
        [ -z "$value" ] && continue
        echo "$var=\"$value\""
    done
}

texlive_test_dist()
{
    texlive_test_dist__tmp=$(mktemp -d)
    (
        set -e
        cd "$texlive_test_dist__tmp"
        echo -n "# TeXlive test with $(which latex) ... "
        if latex small2e >/dev/null; then
            echo  OK
        else
            echo FAILED
        fi
    )
    rm -Rf "$texlive_test_dist__tmp"
}



###

texlive_install()
{
    texlive_env || return 1

    texlive_check_installed
    case $? in
        0)
            return 0
            ;;
        1)
           texlive_install_dist_ext
            ;;
        2)
            texlive_install_dist_local
            ;;
        *)
            return 1
            ;;
    esac
}

texlive_update()
{
    texlive_env || return 1

    texlive_install || return 1
    texlive_update_dist "$@"
}

texlive_status()
{
    texlive_env || return 1

    texlive_check_installed || return 1
    texlive_display_info &&
        texlive_test_dist
}

texlive_test()
{
    texlive_env || return 1

    texlive_check_installed || return 1
    texlive_test_dist
}

texlive_usage()
{
    cat <<EOF
Usage: $0 <command>

with command in:
    install|setup
    update
    info|status
    test
EOF
    exit 1
}



### main

case $1 in
    install|setup)
        shift
        texlive_install "$@"
        ;;
    update)
        shift
        texlive_update "$@"
        ;;
    info|status)
        shift
        texlive_status "$@"
        ;;
    test)
        shift
        texlive_test "$@"
        ;;
    *)
        texlive_usage "$@"
        ;;
esac
