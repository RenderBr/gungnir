#!/bin/zsh
# brew lua@5.4 is keg-only; vendor:lua/5.4 links system:lua5.4, so we must
# point the linker at the keg explicitly.
set -e
cd "$(dirname "$0")"
LUA_LIB="$(brew --prefix lua@5.4)/lib"
mkdir -p bin
odin build src -out:bin/odin-engine -debug -vet \
  -extra-linker-flags:"-L${LUA_LIB}"
