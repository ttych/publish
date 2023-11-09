#!/bin/sh

SCRIPT_NAME="${0##*/}"
SCRIPT_RPATH="${0%$SCRIPT_NAME}"
SCRIPT_PATH=`cd "${SCRIPT_RPATH:-.}" && pwd`


NFCRACK_DIR="${NFCRACK_DIR:-$HOME/etc/nfc}"
NFCRACK_KEYSTORE="${NFCRACK_KEYSTORE:-$NFCRACK_DIR/keystore}"
NFCRACK_DUMP_DIR="${NFCRACK_DUMP_DIR:-$NFCRACK_DIR/dumps}"


NFCRACK_LIBNFC_NFC_LIST=nfc-list
NFCRACK_LIBNFC_NFC_MFSETUID=nfc-mfsetuid
NFCRACK_LIBNFC_NFC_MFCLASSIC=nfc-mfclassic

NFCRACK_MFOC=mfoc

NFCRACK_MFCUK=mfcuk
NFCRACK_MFOC_SLEEP_FIELD_OFF=50
NFCRACK_MFOC_SLEEP_FIELD_ON=100

NFCRACK_CRYPTO1_CRACK=libnfc_crypto1_crack

umask 0077
# set -x


echo2()
{
    echo >&2 "$@"
}

which_check()
{
    which_check="$(which $1)"
    if [ $? -ne 0 ]; then
        echo2 "# $1 not found !"
        return 1
    fi
}

ldd_check()
{
    ldd -u "$1" >/dev/null
    if [ $? -ne 0 ]; then
        echo2 "# $1 has issue with shared object dependencies !"
        return 1
    fi
}


########## tools

nfcrack_dirs()
{
    mkdir -p "$NFCRACK_DIR" || return 1
    [ -f "$NFCRACK_KEYSTORE" ] || touch "$NFCRACK_KEYSTORE" || return 1
    mkdir -p "$NFCRACK_DUMP_DIR" || return 1
}

nfcrack_check_bin()
{
    for nfcrack_check_bin in "$@"; do
        which_check "$nfcrack_check_bin" || return 1
        ldd_check "$which_check" || return 1
    done
}

nfcrack_libnfc_check()
{
    nfcrack_check_bin \
        $NFCRACK_LIBNFC_NFC_LIST \
        $NFCRACK_LIBNFC_NFC_MFSETUID \
        $NFCRACK_LIBNFC_NFC_MFCLASSIC
}

nfcrack_libnfc_nfc_list()
{
    $NFCRACK_LIBNFC_NFC_LIST "$@"
}

nfcrack_libnfc_info()
{
    eval $(nfcrack_libnfc_nfc_list | \
           awk 'BEGIN { uid=""; std=""; atqa=""; sak=""; }
                $1 ~  /ISO\/IEC/ { std="ISO"$2 }
                $1 ~ /ATQA/ { atqa="";
                              for (i = 3; i <= NF; i++) atqa = atqa $i }
                $1 ~ /UID/ { uid="";
                             for (i = 3; i <= NF; i++) uid = uid $i }
                $1 ~ /SAK/ { sak="";
                             for (i = 3; i <= NF; i++) sak = sak $i }
                END { printf("nfcrack_libnfc_info_%s=\"%s\" ", "uid", uid);
                      printf("nfcrack_libnfc_info_%s=\"%s\" ", "std", std);
                      printf("nfcrack_libnfc_info_%s=\"%s\" ", "atqa", atqa);
                      printf("nfcrack_libnfc_info_%s=\"%s\" ", "sak", sak);
                    }')
    [ -z "$nfcrack_libnfc_info_uid" ] && return 1
    return 0
}

nfcrack_mfcuk_check()
{
    nfcrack_check_bin "$NFCRACK_MFCUK"
}

nfcrack_mfcuk()
{
    :
}

nfcrack_mfoc_check()
{
    nfcrack_check_bin "$NFCRACK_MFOC"
}

nfcrack_mfoc()
{
    :
}

nfcrack_crypto1_bs_check()
{
    nfcrack_check_bin "$NFCRACK_CRYPTO1_CRACK"
}

nfcrack_crypto1_bs()
{
    :
}

nfcrack_check()
{
    nfcrack_libnfc_check &&
        nfcrack_mfcuk_check &&
        nfcrack_mfoc_check &&
        nfcrack_crypto1_bs_check &&
        nfcrack_dirs
}

nfcrack_keystore_add()
{
    [ -z "$1" ] && return 1
    [ -f "$NFCRACK_KEYSTORE" ] || touch "$NFCRACK_KEYSTORE" || return 1

    (cat "$NFCRACK_KEYSTORE" ; echo "$1") | sort -u > "$NFCRACK_KEYSTORE.new"
    mv "$NFCRACK_KEYSTORE.new" "$NFCRACK_KEYSTORE"
}


########## action

nfcrack_help()
{
    cat <<EOF
Actions are:
    h | help
    q | quit
      | exit
    i | id
    d | dump
    c | copy
    w | write
    W | wipe
EOF
}

nfcrack_quit()
{
    exit 0
}

nfcrack_debug()
{
    set -x
}

nfcrack_id()
{
    if nfcrack_libnfc_info; then
        printf "_ %s: %s\n" \
               STANDARD "$nfcrack_libnfc_info_std" \
               UID "$nfcrack_libnfc_info_uid" \
               ATQA "$nfcrack_libnfc_info_atqa" \
               SAK "$nfcrack_libnfc_info_sak"
    fi
}

nfcrack_rotate_key()
{
    nfcrack_rotate_key__initial="$1"
    nfcrack_rotate_key=

    while [ -n "$nfcrack_rotate_key__initial" ]; do
        nfcrack_rotate_key__tmp="${nfcrack_rotate_key__initial#??}"
        nfcrack_rotate_key="${nfcrack_rotate_key__initial%$nfcrack_rotate_key__tmp}${nfcrack_rotate_key}"
        nfcrack_rotate_key__initial="${nfcrack_rotate_key__tmp}"
    done
}

nfcrack_try_crypto1_bs()
{
    set -- $(tail -1 "$1" | tr ';' ' ')
    known_key_init=$1
    nfcrack_rotate_key "$known_key_init"
    known_key="$ nfcrack_rotate_key"
    known_sector_num=$2
    known_block_num=$((known_sector_num * 4))
    known_key_letter=$3
    unknown_key_letter=$5
    unknown_sector_num=$4
    unknown_block_num=$((unknown_sector_num * 4))

    nfcrack_try_crypto1_bs__tmp=`mktemp`
    "$NFCRACK_CRYPTO1_CRACK" "$known_key" "$known_block_num" "$known_key_letter" \
                         "$unknown_block_num" "$unknown_key_letter" \
                         "$nfcrack_try_crypto1_bs__tmp" \
                         </dev/null
    nfcrack_try_crypto1_bs=$?

    nfcrack_keystore_add `cat "$nfcrack_try_crypto1_bs__tmp"`
    rm -f "$nfcrack_try_crypto1_bs__tmp" "0x"*".txt"
    return $nfcrack_try_crypto1_bs
}

nfcrack_recover_key()
{
    nfcrack_recover_key=
    nfcrack_recover_key__sector=${1:-0}
    nfcrack_recover_key__key=${2:-A}

    nfcrack_recover_key__output=`mktemp`
    nfcrack_recover_key__status_file=`mktemp`

    ($NFCRACK_MFCUK -C -R ${nfcrack_recover_key__sector}:${nfcrack_recover_key__key} -s $NFCRACK_MFOC_SLEEP_FIELD_OFF -S $NFCRACK_MFOC_SLEEP_FIELD_ON -v 2 </dev/null; echo $? > "$nfcrack_recover_key__status_file") | tee "$nfcrack_recover_key__output"

    nfcrack_recover_key=`cat $nfcrack_recover_key__status_file`
    rm -f "$nfcrack_recover_key__status_file"

    nfcrack_recover_key=$(cat "$nfcrack_recover_key__output" | \
                               awk -v sector=$nfcrack_recover_key__sector -v key=$nfcrack_recover_key__key \
                                   'BEGIN { value = "" }
                           $1 == sector { if (key == "A") { value = $3 } else { value = $11 } }
                           END { print value }')

    [ -n "$nfcrack_recover_key" ] && nfcrack_keystore_add "$nfcrack_recover_key"

    rm -f snapshot.mfd \
       "$nfcrack_recover_key__output" \
       "$nfcrack_recover_key__status_file"

     return $nfcrack_recover_key
}

nfcrack_recover_all_keys()
{
    $NFCRACK_MFCUK -C -R -1 -s $NFCRACK_MFOC_SLEEP_FIELD_OFF -S $NFCRACK_MFOC_SLEEP_FIELD_ON -v 2
}


nfcrack_try_mfoc()
{
    nfcrack_try_mfoc__dump="$1"
    nfcrack_try_mfoc__partial="$2"
    nfcrack_try_mfoc=0

    nfcrack_try_mfoc__output=`mktemp`
    nfcrack_try_mfoc__status_file=`mktemp`

    (mfoc -f "$NFCRACK_KEYSTORE" -O "$nfcrack_try_mfoc__dump" -D "$nfcrack_try_mfoc__partial"; echo $? > $nfcrack_try_mfoc__status_file) | tee "$nfcrack_try_mfoc__output"

    nfcrack_try_mfoc=`cat $nfcrack_try_mfoc__status_file`
    rm -f "$nfcrack_try_mfoc__status_file"

    if [ $nfcrack_try_mfoc -eq 0 ]; then
        nfcrack_try_mfoc__found_key=`cat "$nfcrack_try_mfoc__output" | grep '^  Found Key: ' | sort -u | head -n 1`
        nfcrack_try_mfoc__found_key="${nfcrack_try_mfoc__found_key##* [}"
        nfcrack_try_mfoc__found_key="${nfcrack_try_mfoc__found_key%]*}"
        if [ -n "$nfcrack_try_mfoc__found_key" ]; then
            nfcrack_keystore_add "$nfcrack_try_mfoc__found_key"
        fi
    else
        nfcrack_try_mfoc__first_unknown=`cat "$nfcrack_try_mfoc__output" | grep '^Sector ' | tail -n 16 | grep ' Unknown Key ' | head -n 1`
        nfcrack_try_mfoc__u_sector="${nfcrack_try_mfoc__first_unknown#Sector }"
        nfcrack_try_mfoc__u_sector="${nfcrack_try_mfoc__u_sector%% -*}"
        nfcrack_try_mfoc__u_key="${nfcrack_try_mfoc__first_unknown#* Unknown Key }"
        nfcrack_try_mfoc__u_key="${nfcrack_try_mfoc__u_key%% *}"
    fi

    rm -f "$nfcrack_try_mfoc__output" "$nfcrack_try_mfoc__status_file"
    return $nfcrack_try_mfoc
}

nfcrack_dump()
{
    nfcrack_dump=
    nfcrack_dump__name="$1"
    nfcrack_dump__status=0

    nfcrack_libnfc_info || return 1
    [ -z "$nfcrack_dump__name" ] && nfcrack_dump__name="$nfcrack_libnfc_info_uid"

    nfcrack_dump="$NFCRACK_DUMP_DIR/${nfcrack_dump__name}.`date '+%Y%m%d%H%M%S'`.mfd"
    nfcrack_dump_partial="$NFCRACK_DUMP_DIR/${nfcrack_dump__name}.`date '+%Y%m%d%H%M%S'`.partial"

    while true; do
        nfcrack_try_mfoc "$nfcrack_dump" "$nfcrack_dump_partial"
        if [ $nfcrack_try_mfoc -eq 0 ]; then
            echo "dump to $nfcrack_dump SUCCEEDED\n"
            break
        elif [ $nfcrack_try_mfoc -eq 1 ]; then
            if ! nfcrack_recover_key "$nfcrack_try_mfoc__u_sector" "$nfcrack_try_mfoc__u_key"; then
                nfcrack_dump__status=1
                echo2 "ERROR while recovering key !"
                break
            fi
        elif [ $nfcrack_try_mfoc -eq 9 ]; then
            nfcrack_try_cryto1_bs "$nfcrack_dump_partial" || break
        else
            echo2 "ERROR unknown !"
            nfcrack_dump__status=1
            break
        fi
    done

    rm -f "$nfcrack_dump_partial"
    [ $nfcrack_dump__status -eq 0 ] || rm -f "$nfcrack_dump"

    return $nfcrack_dump__status
}

nfcrack_dispatch()
{
    nfcrack_dispatch__action="$1"
    [ $# -gt 0 ] && shift

    case "$nfcrack_dispatch__action" in
        h|help)
            nfcrack_help
            ;;
        q|quit|exit)
            nfcrack_quit
            ;;
        x|debug)
            nfcrack_debug
            ;;
        i|id)
            nfcrack_id
            ;;
        d|dump)
            nfcrack_dump "$@"
            ;;
        W|wipe)
            # nfckit_wipe
            ;;
        c|copy)
            # nfckit_copy "$@"
            ;;
        w|write)
            # nfckit_write "$@"
            ;;

        "")
            ;;
        *)
            echo2 "unknown action $nfcrack_dispatch__action !"
            ;;
    esac
}

nfcrack_menu_prompt()
{
    printf "%s> " "$*"
}

nfcrack_menu()
{
    while true; do
        nfcrack_menu_prompt
        read nfcrack_menu__command
        nfcrack_dispatch $nfcrack_menu__command
    done
}


########## main

nfcrack_check || exit 1

OPTIND=1
while getopts :hx opt; do
    case $opt in
        h) nfcrack_help
           exit 0
           ;;
        x) nfcrack_debug
           ;;
    esac
done
shift $(($OPTIND - 1))

if [ -z "$1" ]; then
    nfcrack_menu
else
    nfcrack_dispatch "$@"
fi
