#!/bin/sh

WINE_NAME=lotr1

do_init()
{
    [ -d "$HOME/.wwine/$WINE_NAME" ] ||
        wwine "$WINE_NAME" setup win32
}

do_tricks()
(
    wwine "$WINE_NAME" tricks -q \
          winxp \
          corefonts \
          d3dx9 d3dx9_43 \
          oleaut32 \
          mfc42 \
          dotnet40 \
          vcrun2005 vcrun2008 vcrun2010 \
          xact \
          winxp

    # # wwine "$WINE_NAME" tricks -q amstream d3dx9 d3dx9_43 d3dxof devenum dinput8 dirac directmusic directplay dmsynth dotnet20 dsound dxdiag dxdiagn_feb2010 l3codecx mfc42 msxml4 quartz riched20 riched30 vcrun2003 vcrun2005 vcrun2008 vcrun2010 vcrun6 winxp xvid allcodecs wmp10 xact xact_jun2010
    # # icodecs
    # # wwine "$WINE_NAME" tricks -q d3dx9 mfc42 winxp l3codecx corefonts vcrun2005 dirac d3dx9_43 dsound dotnet20 quartz
    # wwine "$WINE_NAME" tricks -q \
    #       winxp \
    #       corefonts vcrun2005 vcrun2008 dotnet20 xact xact_jun2010 openal l3codecx mfc42 quartz d3dx9 d3dx9_43 dsound directshow devenum amstream \
    #       dsound l3codecx directmusic \
    #       winxp &&
    #     wwine age3 exe regsvr32 /u "C:\\windows\\system32\\devenum.dll"
)

do_game()
(
    cd "$1/Game" || return 1
    wwine "$WINE_NAME" exe ./AutoRun.exe || return 1
)

do_patch()
(
    cd "$1" || return 1

    wwine "$WINE_NAME" exe "./Le_Seigneur_des_Anneaux__La_Bataille_pour_la_Terre_du_Milieu_II__65542-french.exe" || return 1
    cp -f "./Le_Seigneur_des_Anneaux__La_Bataille_pour_la_Terre_du_Milieu_II__fix/game.dat" "$HOME/.wwine/$WINE_NAME/drive_c/Program Files/Electronic Arts/La Bataille pour la Terre du Milieu II/game.dat" || return 1

    wwine "$WINE_NAME" exe "./Le_Seigneur_des_Anneaux__La_Bataille_pour_la_Terre_du_Milieu_II__fix/Startup_Fixxer.exe" || return 1

    cp -f "./Le_Seigneur_des_Anneaux__La_Bataille_pour_la_Terre_du_Milieu_II__fix/WSMaps.big" "$HOME/.wwine/$WINE_NAME/drive_c/Program Files/Electronic Arts/La Bataille pour la Terre du Milieu II/" || return 1

    echo "Update resolution in $HOME/.wwine/$WINE_NAME/drive_c/users/thomas/AppData/Roaming/La Bataille pour la Terre du Milieu ™ II/options.ini"
)

do_all()
{
    do_init &&
        do_tricks &&
        do_game "$@"
}

do_clean()
{
    rm -Rf "$HOME/.wwine/$WINE_NAME"
}

case $1 in
    # "")
    #     action=all
    #     shift 2>/dev/null
    #     ;;
    all|game|clean|init|tricks|install|patch)
        action="$1"
        shift
        ;;
    *)
        if [ -d "$1" ]; then
            action=all
        else
            echo "unknown action \"$1\""
            exit 1
        fi
        ;;
esac
do_${action} "$@"
