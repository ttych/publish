#!/bin/sh
# -*- mode: sh -*-

echo2() { echo >&2 "$@"; }

semver_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

handbrake_cli()
{
    handbrake_cli_flatpak_cmd="flatpak run --command=HandBrakeCLI fr.handbrake.ghb"
    handbrake_cli_bin_cmd="HandBrakeCLI"

    handbrake_cli_flatpak_version=$($handbrake_cli_flatpak_cmd --version 2>/dev/null | sed -e 's/^.*\s\([0-9.]*\)$/\1/g' | tr -d "\n\t ")
    handbrake_cli_bin_version=$($handbrake_cli_bin_cmd --version 2>/dev/null | sed -e 's/^.*\s\([0-9.]*\)$/\1/g' | tr -d "\n\t ")

    if semver_gt  "$handbrake_cli_bin_version" "$handbrake_cli_flatpak_version"; then
        echo2 "# using $handbrake_cli_bin_cmd ..."
        $handbrake_cli_bin_cmd "$@"
    else
        echo2 "# using $handbrake_cli_flatpak_cmd ..."
        $handbrake_cli_flatpak_cmd "$@"
    fi
}


case "$0" in
    */handbrake_cli*)
        handbrake_cli "$@"
        ;;
esac
