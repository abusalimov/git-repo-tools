#!/bin/bash
set -e

dir="$(dirname $0)"
cat $dir/empty-dirs-zrv.txt | sed 's/$/.gitkeep/' | git update-index --remove --stdin
