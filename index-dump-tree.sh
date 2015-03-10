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

timestamp=$(echo ${GIT_AUTHOR_DATE#@} | cut -d' ' -f1)

git diff-tree --no-commit-id --no-renames --diff-filter=AM -r $GIT_COMMIT | \
while read old_mode mode old_sha1 sha1 action file; do
	file_dir="$DUMP_DIR/${file// /-}"

	if [ ! -f "$file_dir"/*-$sha1 ]; then
		mkdir -p "$file_dir"
		git checkout-index -f -u -- "$file"
		mv -T "$file" "$file_dir"/$timestamp-$sha1
	fi
done
