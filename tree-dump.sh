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

if [[ -z $OUT_DIR ]] || [[ ! -d $OUT_DIR ]]; then
    >&2 echo "OUT_DIR: $OUT_DIR: no such directory"
    exit 1
fi

for file in $(find . -type f); do
	dest_dir="$OUT_DIR/$file"
	dest_file="$dest_dir/$(set -- $(sha1sum "$file"); echo $1)"

	if [[ ! -f $dest_file ]]; then
		mkdir -p "$dest_dir"
		cp "$file" "$dest_file"
	fi
done
