#!/bin/bash

input="$(cygpath -u "$1")"
output="$(cygpath -u "$2")"
iverilog -o "$output" -DDUMPFILE="\"$(basename "$input" .v).vcd\"" "$input" 
