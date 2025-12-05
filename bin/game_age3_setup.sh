#!/bin/sh

WINE_NAME=age3
GAME_DIR="${GAME_DIR:-$HOME/mnt/age3}"

do_wwine()
{
    rm -Rf "$HOME/.wwine/$WINE_NAME" &&
        wwine "$WINE_NAME" setup win32
}

do_tricks()
{
    # wwine "$WINE_NAME" tricks -q amstream d3dx9 d3dx9_43 d3dxof devenum dinput8 dirac directmusic directplay dmsynth dotnet20 dsound dxdiag dxdiagn_feb2010 l3codecx mfc42 msxml4 quartz riched20 riched30 vcrun2003 vcrun2005 vcrun2008 vcrun2010 vcrun6 winxp xvid allcodecs wmp10 xact xact_jun2010
    # icodecs
    # wwine "$WINE_NAME" tricks -q d3dx9 mfc42 winxp l3codecx corefonts vcrun2005 dirac d3dx9_43 dsound dotnet20 quartz
    wwine "$WINE_NAME" tricks -q \
          winxp \
          corefonts vcrun2005 vcrun2008 dotnet20 xact xact_jun2010 openal l3codecx mfc42 quartz d3dx9 d3dx9_43 dsound directshow devenum amstream \
          dsound l3codecx directmusic \
          winxp &&
        wwine age3 exe regsvr32 /u "C:\\windows\\system32\\devenum.dll"
}

do_install()
{
    wwine age3 exe "${1:-GAME_DIR}/install.exe" &&
        cp "$HOME/.wwine/$WINE_NAME/drive_c/Program Files/Microsoft Games/Age of Empires III/age3.exe" "$HOME/.wwine/$WINE_NAME/drive_c/Program Files/Microsoft Games/Age of Empires III/age3.exe.orig" &&
        cp "${1:-GAME_DIR}/fix/age3.exe" "$HOME/.wwine/$WINE_NAME/drive_c/Program Files/Microsoft Games/Age of Empires III/age3.exe" &&
        wwine age3 exe "${1:-GAME_DIR}/patches/aoe3-114-french.exe"

    # wwine age3 exe "${1:-GAME_DIR}/patches/aoe3-112-french.exe" &&
        # wwine age3 exe "${1:-GAME_DIR}/patches/aoe3-113-french.exe" &&
}

do_all()
{
    do_wwine &&
        do_tricks &&
        do_install "$@"
}


case $1 in
    all|wwine|tricks|install)
        action="$1"
        shift
        ;;
    *)
        action=all
        ;;
esac
do_${action} "$@"
