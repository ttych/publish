#!/bin/sh


SCRIPT_NAME="${0##*/}"
SCRIPT_RPATH="${0%$SCRIPT_NAME}"
SCRIPT_PATH=`cd "${SCRIPT_RPATH:-.}" && pwd`


echo2()
{
    echo >&2 "$@"
}


######################################### 1. scan
# HandBrakeCLI -i "input.iso" --scan

######################################### 2. encode
# Prefer mp4 format:
# --format=av_mp4 \

# Want 2 pass encoding
# --two-pass \
# --turbo \

# Play with default subtitle
# --subtitle-default=1 \

# Subtitle scan
# --subtitle-lang-list=eng \
# --subtitle=scan \

echo2()
{
    echo >&2 "$@"
}

usage()
{
    cat <<EOF
usage is:
  $0 ...

with options:
  -t title1,title2,...
  -a audio1,audio2,...
  -s subtitle1,subtitle2,...
  -q quality_rate (default: 20)
  -f format (default: mkv)  [mkv, mp4, ...]
EOF
}

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


FORMAT="${FORMAT:-mkv}"
TITLE=
AUDIO=
SUBTITLE=
VIDEO_ENCODER_TYPE=av1
AUDIO_ENCODER_TYPE=aac
TEST=
TEST_START=600
TEST_DURATION=180

OPTIND=1
while getopts :xhf:t:a:s:q:V:A:T opt; do
  case $opt in
        x) set -x ;;
        h) usage ; exit 0 ;;
        f) FORMAT="$OPTARG" ;;
        t) TITLE="$OPTARG" ;;
        a) AUDIO="$OPTARG" ;;
        s) SUBTITLE="$OPTARG" ;;
        q) VIDEO_QUALITY="$OPTARG" ;;
        V) VIDEO_ENCODER_TYPE="$OPTARG" ;;
        A) AUDIO_ENCODER_TYPE="$OPTARG" ;;
        T) TEST=1 ;;
    esac
done
shift $(($OPTIND - 1))

case $VIDEO_ENCODER_TYPE in
  h265|x265)
    VIDEO_ENCODER=x265_10bit
    VIDEO_ENCODER_PRESET=veryslow
    VIDEO_ENCODER_PROFILE="${VIDEO_ENCODER_PROFILE:-main10}"
    VIDEO_QUALITY="${VIDEO_QUALITY:-20}"
    ;;
  h264|x264)
    VIDEO_ENCODER=x264_10bit
    VIDEO_ENCODER_PRESET=veryslow
    VIDEO_ENCODER_PROFILE="${VIDEO_ENCODER_PROFILE:-high}"
    VIDEO_QUALITY="${VIDEO_QUALITY:-20}"
    ;;
  av1)
    VIDEO_ENCODER=svt_av1_10bit
    VIDEO_ENCODER_PRESET=2
    VIDEO_ENCODER_PROFILE="${VIDEO_ENCODER_PROFILE:-main}"
    VIDEO_QUALITY="${VIDEO_QUALITY:-25}"
    ;;
  *) echo2 "unsupported video encoder type: $VIDEO_ENCODER_TYPE"
     exit 1
     ;;
esac

case $AUDIO_ENCODER_TYPE in
  aac)
    AUDIO_ENCODER=av_aac
    AUDIO_BITRATE=192
    ;;
  *) echo2 "unsupported audio encoder type: $AUDIO_ENCODER_TYPE"
     exit 1
     ;;
esac

SOURCE="$1"
if [ ! -r "$SOURCE" ]; then
    echo2 "$SOURCE is not readable"
    exit 1
fi


if [ -z "$AUDIO" ] || [ -z "$SUBTITLE" ]; then
    handbrake_cli \
        -i "$SOURCE" \
        --main-feature \
        --scan
fi
if [ -z "$TITLE" ]; then
    printf "Select TITLE ids : "
    read TITLE
fi
if [ -z "$AUDIO" ]; then
    printf "Select AUDIO ids : "
    read AUDIO
fi
if [ -z "$SUBTITLE" ]; then
    printf "Select SUBTITLE ids : "
    read SUBTITLE
fi


audio_encoders=$(echo "$AUDIO" | sed "s/[^,]*/$AUDIO_ENCODER/g")
audio_bitrates=$(echo "$AUDIO" | sed "s/[^,]*/$AUDIO_BITRATE/g")


TARGET="${SOURCE}.t${TITLE}.${VIDEO_ENCODER_TYPE}_${VIDEO_QUALITY}.${FORMAT}"


handbrake_cli \
    -i "$SOURCE" \
    -o "$TARGET" \
    --title="$TITLE" \
    --format="av_${FORMAT}" \
    --crop auto \
    --markers \
    --audio="$AUDIO" \
    --aencoder="$audio_encoders" \
    --ab="$audio_bitrates" \
    --subtitle="$SUBTITLE" \
    --encoder="$VIDEO_ENCODER" \
    --encoder-preset="$VIDEO_ENCODER_PRESET" \
    --encoder-profile="$VIDEO_ENCODER_PROFILE" \
    --quality="$VIDEO_QUALITY" \
    --comb-detect="default" \
    --deinterlace="default" \
    ${TEST:+--start-at duration:$TEST_START --stop-at duration:$TEST_DURATION}

    # --encoder-level=4.1 \
    # --mixdown=stereo \
