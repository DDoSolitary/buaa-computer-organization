#!/bin/bash

file="$1"
if command -v cygpath > /dev/null; then file="$(cygpath -u "$file")"; fi
out_dir="$(dirname "$file")"
proj_dir="$(dirname "$out_dir")"
proj_name="$(basename "$proj_dir")"

cd "$out_dir"
if [ -f "$proj_name" ]; then
	cp ../code.txt .
	vvp "$proj_name"
else
	vvp "$file"
fi
gtkwave "$file.vcd"
