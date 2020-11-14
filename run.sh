#!/bin/bash

file="$1"
if command -v cygpath > /dev/null; then file="$(cygpath -u "$file")"; fi

cd "$(dirname "$file")"
vvp "$file"
gtkwave "$file.vcd"
