#!/bin/sh
# -*- mode: sh -*-

SCRIPT_NAME="${0##*/}"
SCRIPT_RPATH="${0%$SCRIPT_NAME}"
SCRIPT_PATH=`cd "${SCRIPT_RPATH:-.}" && pwd`


printf2()
{
  printf >&2 "%s\n" "$@"
}



########### ffmpeg

has_ffmpeg()
{
  which ffmpeg >/dev/null 2>/dev/null
}

_ffmpeg()
{
  ffmpeg -hide_banner -loglevel error "$@"
}

_ffprobe()
{
  ffprobe -v error "$@"
}



########### video

video_list_audio_streams()
{
  OPTIND=1
  while getopts :xa: opt; do
    case $opt in
      a) video_list_audio_streams__atrack="$OPTARG" ;;
      x) set -x ;;
    esac
  done
  shift $(($OPTIND - 1))

  _ffprobe -select_streams a${video_list_audio_streams__atrack:+:$video_list_audio_streams__atrack} \
           -show_entries stream=index,codec_name \
           -of csv=p=0 \
           "$@"
}



########### audio

audio_codec_to_ext()
{
  audio_codec_to_ext="nop"
  case "$1" in
    aac|alac)       audio_codec_to_ext="m4a"  ;;
    mp3)            audio_codec_to_ext="mp3"  ;;
    ac3)            audio_codec_to_ext="ac3"  ;;
    eac3)           audio_codec_to_ext="eac3" ;;
    dts)            audio_codec_to_ext="dts"  ;;
    opus)           audio_codec_to_ext="opus" ;;
    vorbis)         audio_codec_to_ext="ogg"  ;;
    flac)           audio_codec_to_ext="flac" ;;
    truehd)         audio_codec_to_ext="thd"  ;;
    wmav1|wmav2)    audio_codec_to_ext="wma"  ;;
    pcm_*)          audio_codec_to_ext="wav"  ;;
    *)              printf2 "unsupported audio codec \"$1\""
                    return 1 ;;
  esac
}

audio2wav()
{
  _ffmpeg -i "$1" -ar 48000 -ac 1 -c:a pcm_s24le "${1%.*}.wav"
}

audiofrom()
{
  audiofrom_usage()
  {
    cat >&2 <<EOF
Usage: audiofrom <FILE> ...
Options:
    -h      : help
    -x      : debug
    -a      : audio relative track
    -s      : start time
    -t      : duration
    -e      : end time
EOF
  }

  audiofrom__track=
  audiofrom__start=
  audiofrom__duration=
  audiofrom__end=

  OPTIND=1
  while getopts :hxa:s:t:e: opt; do
    case $opt in
      a) audiofrom__atrack="$OPTARG" ;;
      s) audiofrom__start="$OPTARG" ;;
      t) audiofrom__duration="$OPTARG" ;;
      e) audiofrom__end="$OPTARG" ;;
      h) audiofrom_usage ; exit 0 ;;
      x) set -x ;;
    esac
  done
  shift $(($OPTIND - 1))

  audiofrom__input="$1"
  if [ $# -eq 0 ] || [ -z "$audiofrom__input" ]; then
    audiofrom_usage
    return 1
  fi
  if [ ! -r "$audiofrom__input" ]; then
    printf2 "audiofrom can't read \"$audiofrom__input\""
    return 1
  fi

  for audiofrom__astream in $(video_list_audio_streams ${audiofrom__atrack:+-a $audiofrom__atrack} "$1"); do
    audiofrom__astream_id="${audiofrom__astream%%,*}"
    audiofrom__astream_codec="${audiofrom__astream##*,}"
    audio_codec_to_ext "$audiofrom__astream_codec"
    audiofrom__astream_ext="$audio_codec_to_ext"
    audiofrom__ouput="${audiofrom__input%.*}.${audiofrom__astream_id}.${audiofrom__astream_ext}"

    _ffmpeg \
      -i "$audiofrom__input" \
      ${audiofrom__start:+-ss $audiofrom__start} ${audiofrom__duration:+-t $audiofrom__duration} ${audiofrom__end:+-to $audiofrom__end} \
      -map 0:"$audiofrom__astream_id" \
      -c:a copy \
      "$audiofrom__ouput"
  done
}



########### main

case "$SCRIPT_NAME" in
  video*) "$SCRIPT_NAME" "$@" ;;
  audio*) "$SCRIPT_NAME" "$@" ;;
  *) printf2 "\"$SCRIPT_NAME\" is not a valid command."
     exit 1
     ;;
esac
