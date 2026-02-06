#!/bin/sh
# -*- mode: sh -*-

echo2()
{
    echo >&2 "$@"
}

project_root_dir()
{
    project_root_dir=
    project_root_dir=$(git rev-parse --git-dir)
    project_root_dir="${project_root_dir%.git}"
}

copilot_init()
{
    copilot_init__root="$1"
    [ -n "$copilot_init__root" ] && [ -d "$copilot_init__root" ] || return 1

    mkdir -p "$copilot_init__root/.copilot" || return 1
}

copilot_mgr()
{
    copilot_mgr__arg_dir="$1"
    copilot_mgr__root=
    project_root_dir
    for d in "$copilot_mgr__root" "$copilot_mgr__arg_dir" "$PWD"; do
        [ -z "$d" ] && continue
        [ -d "$d" ] || continue
        copilot_mgr__root="$d"
    done
    if [ -z "$copilot_mgr__root" ]; then
        echo2 "No valid root directory found"
        return 1
    fi

    copilot_init "$copilot_mgr__root"
}


########### main
copilot_mgr "$@"
