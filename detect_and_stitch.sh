#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Convenience script for running YOLO on five dome camera videos."
    echo "Usage: $0 INPUTDIR OUTPUTVIDEO OUTPUTTEXT [ARGS]"
    echo "  INPUTDIR: Directory with cam_back.mp4, cam_left.mp4, cam_front.mp4, "
    echo "    cam_right.mp4, cam_top.mp4"
    echo "  OUTPUTVIDEO: File name for the stitched detections video (.mp4)"
    echo "  OUTPUTTEXT: File name for the detection text files (.tgz)"
    echo "  ARGS: Further arguments given to detect.py (such as --weights=..., --augment)"
    exit
fi

here="${0%/*}"
inputdir="$1"
outputvideo="$2"
outputtext="$3"

tmpdir=$(mktemp -d)
trap 'rm -r "$tmpdir"' EXIT

# run YOLO
for fn in cam_{back,left,front,right,top}.mp4; do
    python3 "$here"/detect.py --source "$inputdir"/"$fn" --img-rotate=180 --output "$tmpdir"/"${fn%.mp4}"/ --device=0 --classes $(cut -d, -f1 "$here"/coco-audio-categories.txt) --save-txt "${@:4}"
done

# collect text results
tar -czf "$outputtext" -C "$tmpdir" "$tmpdir"/cam_*/cam_*.txt

# stitch result videos
ffmpeg -y \
    -i "$tmpdir"/cam_back/cam_back.mp4 \
    -i "$tmpdir"/cam_right/cam_right.mp4 \
    -i "$tmpdir"/cam_front/cam_front.mp4 \
    -i "$tmpdir"/cam_left/cam_left.mp4 \
    -i "$tmpdir"/cam_top/cam_top.mp4 \
    -filter_complex hstack=inputs=5 \
    "$outputvideo"
