#!/bin/bash

cd "$(cygpath -u "$1")"
make
