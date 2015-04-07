#!/bin/bash

set -e
#set -x

while [[ $# > 0 ]]; do
	file="$1"
	file_dir="$DUMP_DIR/${file// /-}"

	sha1=$(git hash-object --no-filters -- "$file") || { >&2 echo $file; exit 1; }

	dump_file=
	if [ -d "$file_dir" ]; then
		while read -r -d $'\0' df; do
		# printf "%s\0" "$file_dir"/*-$sha1 | sort -z -V | while read -r -d $'\0' df; do
			timestamp=$(basename $df | cut -d- -f1)
			if (( timestamp > TIMESTAMP )); then
				break
			fi
			dump_file="$df"
		done < <(find "$file_dir" -type f -name \*-$sha1 -print0)
	fi

	if [[ ! "$dump_file" ]]; then
		rm "$file"

	elif [ -f "$dump_file" ]; then
		cp --no-preserve=all -d -T "$dump_file" "$file"
		if [ "$file" != "${file// /_}" ]; then
			mkdir -p $(dirname "${file// /_}")
			mv -T "$file" "${file// /_}"
		fi

	else
		>&2 echo "Unknown file type: $dump_file"
		exit 1
	fi

	shift
done

