#!/bin/bash
#
# dump_dir=/tmp/git-dump
# git filter-branch \
#     --tree-filter "tree-from-dump.sh $dump_dir" \
# --tag-name-filter cat -- --all
#
set -e
#set -x

export DUMP_DIR="$1"

if [[ -z $DUMP_DIR ]]; then
	>&2 echo "Usage: $0 <dump-dir>"
	exit 1
fi

dir="$(dirname $0)"
read -r TIMESTAMP _ <<< "${GIT_AUTHOR_DATE#@}"
export TIMESTAMP

find . -type f -print0 | xargs -0 -P12 -n8  "$dir/tree-from-dump-each.sh"

find . -type l -print0 | while read -r -d $'\0' file; do
	file_dir="$DUMP_DIR/${file// /-}"
	if ! [ -e "$file_dir" ]; then
		>&2 echo rm "$file"
		rm "$file"
	fi
done

find "$DUMP_DIR" -type f -maxdepth 1 -name \*.sh -print0 | sort -z -V | \
		while read -r -d $'\0' script; do
	IFS="-." read -r begin end ext < <(basename "$script")
	if [[ ! $ext ]]; then
		ext="$end"
		end=
	fi
	if [[ $ext != "sh" || ! "$begin$end" =~ [0-9]+ ]]; then
		>&2 echo "Unable to parse dump script name: $script: $begin $end $ext"
		exit 1
	fi

	if [[ $begin ]] && (( begin > TIMESTAMP )); then
		continue
	fi
	if [[ $end ]] && (( end <= TIMESTAMP )); then
		continue
	fi

	eval "$script"
done

