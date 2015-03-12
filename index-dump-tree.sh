#!/bin/bash
#
# dump_dir=/tmp/git-dump
# git filter-branch \
#     --index-filter "index-dump-tree.sh $dump_dir" \
# -- --all
#
# Dumps a tree with all file versions ever existed in the repo.
# Useful for efficient further inspection (grep, ctags, etc.).
#
set -e

DUMP_DIR="$1"

if [[ -z $DUMP_DIR ]]; then
	>&2 echo "Usage: $0 <dump-dir>"
	exit 1
fi
mkdir -p "$DUMP_DIR"

read -r timestamp _ <<< "${GIT_AUTHOR_DATE#@}"

git diff-tree --root --no-commit-id --no-renames --diff-filter=AM -c -r -z \
	$GIT_COMMIT | \
while read -r -d $'\0' -a metadata; do
	sha1=${metadata[-2]}

	read -r -d $'\0' file
	file_dir="$DUMP_DIR/${file// /-}"

	if [ ! -f "$file_dir"/*-$sha1 ]; then
		mkdir -p "$file_dir"
		git checkout-index -f -u -- "$file"
		mv -T "$file" "$file_dir"/$timestamp-$sha1
	fi
done
