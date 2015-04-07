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



find . -depth -type f | pcregrep '(?x) ^\./(
	src/arch/icebreak.*
) / \d+-[0-9a-f]{40} $ ' | xargs rm -vf

find . -depth -type d -empty -exec rm -rvf '{}' \; \
| (egrep '^removed directory' || true)


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

	for f in $(find $files -type f); do
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

function on_bogus_ifconfig() {
	local n=$(basename $f | cut -d- -f1)
	if (( n < 1262104596 )); then
		"$@"
	else
		cat
	fi
}


fix -v pcregrep -v '(?x)
		  ICEBREAK
		| RXERRS
		| VERSION
	' -- \
	conf/tests.conf \
	conf/usr.conf \
	include/on_boot_express_tests.h \
	include/kernel/init.h \
	scripts/autoconf \
	scripts/autoconf.default \
	scripts/autoconf.h \
	scripts/autoconf.h.in \
	scripts/autoconf.in \
	scripts/autoconf_mb \
	scripts/on_boot_express_tests.h \
	templates/microblaze/embox-usr.conf \
	templates/microblaze/tests.conf \
	templates/microblaze/usr.conf \
	templates/sparc/tests.conf \
	templates/sparc/usr.conf


fix -v $TOOLS_DIR/cleanup-json.py \
	--words 'icebreak' \
	-- \
	.config \
	.config.default \
	.config.in \
	config \
	config.default \
	scripts/.config.in


fix -v pcregrep -v '"version' \
	-- \
	src/conio/shell.inc \
	src/conio/start_script.inc \
	src/conio/tests.inc \
	src/conio/shell.c \
	src/conio/shell.h

fix -v perl_sed 's/,(?=\s*\Z)//m' \
	-- src/conio/shell.inc

fix -v perl_sed 's/\(.icebreak., 1\), \(.x86., 2\)/('"'"'x86'"'"', 1)/g' \
	-- configure.py


fix -v on_bogus_ifconfig pcregrep -v 'IFCONFIG' \
	-- \
	scripts/autoconf \
	scripts/autoconf.default \
	scripts/autoconf.h \
	scripts/autoconf.h.in \
	scripts/autoconf.in \
	scripts/autoconf_mb



fix -v perl_sed 's/(?<=\)),\n\s*.icebrick.*?\((.|\n)*?\)//g' \
	-- \
	scripts/config-builder_2_0/mcglobals.py \
	scripts/config-builder_2_0/ui/mcglobals.py \
	scripts/ConfigBuilder/Parser/mcglobals.py

fix -v pcregrep -Mv '^[^\S\n]*(if|else|elif)\b.*\n.*icebrick' \
	-- \
	scripts/config-builder_1_0/configure.py \
	scripts/ConfigBuilder/TkGui/confmain.py \
	scripts/configure.py


fix -v pcregrep -v '(?i)icebrick' \
	-- \
	scripts/autoconf \
	scripts/autoconf.default \
	scripts/autoconf.h \
	scripts/autoconf.h.in \
	scripts/autoconf.in \
	scripts/autoconf_mb \
	scripts/config.h \
	src/arch/Makefile \
	mk/main.mk

fix -v perl_sed 's/\("sparc", "icebrick"\)/("sparc",)/g' \
	-- \
	scripts/config-builder_1_0/configure_gen.py \
	scripts/config-builder_1_0/configure_gui.py \
	scripts/ConfigBuilder/CodeGen/confgen.py \
	scripts/ConfigBuilder/TkGui/confgen.py \
	scripts/ConfigBuilder/TkGui/confgui.py \
	scripts/configure.py \
	scripts/configure_gen.py \
	scripts/configure_gui.py

fix -v perl_sed 's/ICEBRICK_REGISTERS_QUANTITY/MICROBLAZE_REGISTERS_QUANTITY/g' \
	-- \
	include/asm-microblaze/cpu_context.h \
	src/arch/microblaze/include/asm/cpu_context.h

fix -v perl_sed 's/[^\S\n]*\/[\/*]FIX.*icebrick.*$//mg' \
	-- \
	src/kernel/irq.c \
	src/lib/stdlib/stdlib.c \
	src/lib/stdlib/strtol.c

fix -v perl_sed 's/ in icebrick gcc//g' \
	-- \
	src/tests/compiler/compiler_mem_alloc.c \
	src/tests/compiler_mem_alloc/compiler_mem_alloc.c \
	src/testsuites/compiler_mem_alloc/compiler_mem_alloc.c
