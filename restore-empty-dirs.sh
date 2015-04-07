#!/bin/bash
set -e

export SVN_REPO="$1"

if [[ -z $SVN_REPO ]]; then
	>&2 echo "Usage: $0 <svn-repo>"
	exit 1
fi

dir="$(dirname $0)"
read -r TIMESTAMP _ <<< "${GIT_AUTHOR_DATE#@}"

((TIMESTAMP++))

cat $dir/empty-dirs.txt | sed 's/$/.gitkeep/' | xargs rm -f

svn ls -R file://$SVN_REPO -r "{$(date --date @$TIMESTAMP -u -Iseconds)}" | \
	$dir/filter-empty-dirs.py | grep -x -f $dir/empty-dirs.txt | \
	while read d; do
	echo TOUCH $d.gitkeep
	mkdir -p $d
	touch $d.gitkeep
done || true

cat $dir/empty-dirs.txt | sed 's/$/.gitkeep/' | git update-index --add --remove --stdin
