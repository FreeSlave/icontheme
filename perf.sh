#!/bin/bash

set -x

COMMON_PATH=./examples/findicon/bin
INPUT_VER=$COMMON_PATH/findicon_input
OUTPUT_VER=$COMMON_PATH/findicon_output

if [ -z $1 ]; then
    ICON=folder
else
    ICON=$1
fi

if [ -z $2 ]; then
    THEME=gnome
else
    THEME=$2
fi

strace -c -e trace=stat $INPUT_VER --theme=$THEME --size=32 $ICON
strace -c -e trace=stat $OUTPUT_VER --theme=$THEME --size=32 $ICON

strace -c -e trace=stat $INPUT_VER --theme=$THEME --size=64 $ICON
strace -c -e trace=stat $OUTPUT_VER --theme=$THEME --size=64 $ICON

strace -c -e trace=stat $INPUT_VER --theme=$THEME $ICON
strace -c -e trace=stat $OUTPUT_VER --theme=$THEME $ICON
