#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Convenience script for running YOLO on five dome camera videos, by"
    echo "first stitching them into a more or less seamless joint video."
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

# stitch videos
# borrom row: back right front left back, rotated by 180 degrees
# top row: top top top top top, in different rotations
# all cropped by 320 pixels on the top and right
mkdir "$tmpdir"/input
ffmpeg \
    -i "$inputdir"/cam_back.mp4 \
    -i "$inputdir"/cam_right.mp4 \
    -i "$inputdir"/cam_front.mp4 \
    -i "$inputdir"/cam_left.mp4 \
    -i "$inputdir"/cam_top.mp4 \
    -filter_complex '[0][3][2][1][0]hstack=inputs=5,transpose=cclock,transpose=cclock[bottom];
                   [4]transpose=clock[b];
                   [4]transpose=cclock,transpose=cclock[c];
                   [4]transpose=cclock[d];
                   [4][b][c][d][4]hstack=inputs=5[top];
                   [top][bottom]vstack=inputs=2,crop=w=iw-320:h=ih-320:x=0:y=320' \
    "$tmpdir"/input/cam_2x5.mp4

# run YOLO
python3 "$here"/detect.py \
    --source "$tmpdir"/input/cam_2x5.mp4 \
    --img-size=2880 \
    --output "$tmpdir"/output/ \
    --device=0 \
    --classes $(cut -d, -f1 "$here"/coco-audio-categories.txt) \
    --save-txt \
    "${@:4}"

# collect text results
tar -czf "$outputtext" -C "$tmpdir" "$tmpdir"/output/cam_*.txt

# move result video
mv "$tmpdir/output/cam_2x5.mp4" "$outputvideo"
