#!/usr/bin/env bash
# Locate the Lua 5.4 library for the linker.
# - macOS: brew's lua@5.4 is keg-only, so pass its lib path explicitly.
# - Linux: Odin's vendor:lua/5.4 bundles a static liblua54.a (amd64) or
#   links system:lua5.4 from a standard path, so no extra flags are needed.
set -e
cd "$(dirname "$0")"
mkdir -p bin

case "$(uname -s)" in
  Darwin)
    LUA_LIB="$(brew --prefix lua@5.4)/lib"
    odin build src -out:bin/gungnir -debug -vet \
      -extra-linker-flags:"-L${LUA_LIB}"
    ;;
  *)
    odin build src -out:bin/gungnir -debug -vet
    ;;
esac
