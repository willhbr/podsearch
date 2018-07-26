#!/bin/bash

set -e

infile="${1?}"
transcription="${infile}-transcript.txt"
log="$infile.log"

if [ -f "$infile.wav" ]; then
  rm "$infile.wav"
fi

ffmpeg -i "$infile" -acodec pcm_s16le -ar 16000 -ac 1 "$infile.wav"
pocketsphinx_continuous -infile "$infile.wav" -time 1 2> "$log"
