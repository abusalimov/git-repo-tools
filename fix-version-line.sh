#!/bin/bash
#
# dump_dir=/tmp/git-dump; cd $dump_dir
# ./fix-dump.sh
#
# See also: tree-dump.sh
#
set -e

TOOLS_DIR=$(dirname $0)
MIGR_DIR=~/git-svn-migration

# export TMPDIR=$TMPDIR/grt-fix.sr6a
export TMPDIR=$(mktemp -d --tmpdir grt-fix.XXXX)
trap "rm -rf $TMPDIR" EXIT

TMP_FILE=$TMPDIR/tmp

function perl_sed() { perl -0777 -pe "$@"; }


declare -A show_once

function fix() {
	local verbose=""
	if [[ $1 == -v ]]; then
		verbose=$1; shift
	fi

	local script="$1"
	local args=()

	while [ "$#" -gt 0 ]; do
		shift
		case $1 in
			(--) shift; break;;
			(*) args+=("$1");;
		esac
	done

	echo ========================================================================
	echo
	echo "$script" "${args[@]}"
	echo

	local files="$@"
	if [[ -z "$files" ]]; then
		>&2 echo "No files specified!"
		exit 1
	fi

	for f in $(find $files -type f | \
				pcregrep 'COPYRIGHT|[Mm]akefile|\.(mk|em|lds|[chS])/\d+-[0-9a-f]{40}$'); do
		if "$script" "${args[@]}" < $f > $TMP_FILE && ! cmp -s $f $TMP_FILE; then
			if [[ $verbose ]]; then
				local diff_hash=$(set -- $(sha1sum <(diff -u $f $TMP_FILE | tail -n +4)); echo $1)
				if [[ -z ${show_once[$diff_hash]} ]]; then
					show_once[$diff_hash]=1
					echo
					echo $f
					git diff --no-index --color=always \
						$f $TMP_FILE | tail -n +5 || true
						# --word-diff=color --word-diff-regex='[[:alnum:]]+' \

				else
					echo $f
				fi
			fi

			cat < $TMP_FILE > $f
		fi
	done
}

fix -v perl_sed 's/
	(?<id> \$ \ ? Id(:(?!.*?(Exp|astyanax)).*)? \ ? \$){0}
	( \/\*\*?\s* (?&id) \s*\*\*?\/(\n(?=\n))*
	| (?<=[\/ *]\*)\s* (?&id) (\n[ *]\*$)?
	| \# \s* (?&id) \n (\#?\n(?=\n?\#\n))* )
	//ixmg' -- .

fix -v perl_sed 's/^# -\*- Makefile-gmake -\*-\n+//mg' \
	-- .
