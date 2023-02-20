#!/bin/sh

rm -Rf ~/.wwine/age3
wwine age3 setup win32
sleep 5
wwine age3 tricks -q amstream d3dx9 d3dx9_43 d3dxof devenum dinput8 dirac dmsynth dsound dxdiag dxdiagn_feb2010 ffdshow l3codecx msxml4  vb5run vcrun2003 vcrun2005 vcrun6 xvid
sleep 5
wwine age3 exe /share/games/Windows/Age.of.Empires.III.extracted/install.exe
sleep 5
cp /share/games/Windows/Age.of.Empires.III.extracted/SACRED/age3.exe  ~/.wwine/age3/drive_c/Program\ Files/Microsoft\ Games/Age\ of\ Empires\ III/age3.exe
sleep 5
wwine age3 exe /share/games/Windows/Age.of.Empires.III/patches/aoe3-112-french.exe
sleep 5
wwine age3 exe /share/games/Windows/Age.of.Empires.III/patches/aoe3-114-french.exe

cat <<EOF
to launch:

  wwine age3 exe age3.exe
EOF
