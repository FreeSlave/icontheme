#!/bin/bash

set -ex

COMMON_PATH=./examples/findicon/bin

dub build -b release :findicon --compiler=ldc2
mv $COMMON_PATH/findicon $COMMON_PATH/findicon_input

dub build -b release --config=output :findicon --compiler=ldc2
mv $COMMON_PATH/findicon $COMMON_PATH/findicon_output
