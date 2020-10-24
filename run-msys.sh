#!/bin/bash

dir="$(cygpath -u "$1")"
input="$(cygpath -u "$2")"
cd "$dir"
vvp "$input"
gtkwave "$input.vcd"
