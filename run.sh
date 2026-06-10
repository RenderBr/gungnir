#!/bin/zsh
set -e
cd "$(dirname "$0")"
./build.sh
exec ./bin/odin-engine "$@"
