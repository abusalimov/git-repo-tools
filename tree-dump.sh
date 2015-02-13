#!/bin/bash
#
# dump_dir=/tmp/git-dump; mkdir -p $dump_dir
# git filter-branch \
#     --tree-filter "tree-dump.sh $dump_dir" \
# --tag-name-filter cat -- --all
#
# Dumps a tree with all file version ever existed in the repo.
# Useful for efficient further inspection (grep, ctags, etc.).
#
set -e

OUT_DIR="$1"

if [[ -z $OUT_DIR ]]; then
    >&2 echo "Usage: $0 out_dir"
    exit 1
fi
mkdir -p "$OUT_DIR"

for file in $(find . -type f); do
	dest_dir="$OUT_DIR/$file"
	commit_timestamp=$(echo ${GIT_AUTHOR_DATE#@} | cut -d' ' -f1)
	file_hash=$(sha1sum "$file" | cut -d' ' -f1)

	if [ ! -f "$dest_dir"/*-$file_hash ]; then
		mkdir -p "$dest_dir"
		cp "$file" $dest_dir/$commit_timestamp-$file_hash
	fi
done
