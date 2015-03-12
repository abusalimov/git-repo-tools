#!/bin/bash
#
# dump_dir=/tmp/git-dump
# git filter-branch \
#     --tree-filter "tree-from-dump.sh $dump_dir" \
# --tag-name-filter cat -- --all
#
set -e

DUMP_DIR="$1"

if [[ -z $DUMP_DIR ]]; then
	>&2 echo "Usage: $0 <dump-dir>"
	exit 1
fi

find . \( -type f -o -type l \) -print0 | while read -r -d $'\0' file; do
	file_dir="$DUMP_DIR/${file// /-}"
	sha1=$(git hash-object --no-filters -- "$file")

	if [ -f "$file_dir"/*-$sha1 ]; then
		cp -d --preserve=all -T $(set -- "$file_dir"/*-$sha1; echo $1) "$file"
		if [ "$file" != "${file// /-}" ]; then
			mv -T "$file" "${file// /-}"
		fi
	else
		rm "$file"
	fi
done
find . -depth -type d -empty -exec rmdir '{}' \+
