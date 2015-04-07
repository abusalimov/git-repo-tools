#!/bin/bash
#
# dump_dir=/tmp/git-dump; cd $dump_dir
# ./fix-and-test.sh
#
# See also: tree-dump.sh
#
set -e

TOOLS_DIR=$(dirname $0)

BAD_SOURCES=$TOOLS_DIR/bad-sources.txt
BAD_SYMBOLS=$TOOLS_DIR/bad-symbols.txt
GOOD_SOURCES=$TOOLS_DIR/good-sources.txt
GOOD_SYMBOLS=$TOOLS_DIR/good-symbols.txt

export DUMP_ORIG="$PWD"

export TMPDIR=/tmp/git-test; mkdir -p $TMPDIR
# export TMPDIR=$(mktemp -d --tmpdir grt-fix.XXXX)
# trap "rm -rf $TMPDIR" EXIT
echo "$(basename $0): TMPDIR: $TMPDIR"

cp -r . $TMPDIR/dump
cd $TMPDIR/dump

# /bin/bash $TOOLS_DIR/fix-ovk-again.sh
# exit

$TOOLS_DIR/fix-dump.sh


# $TOOLS_DIR/find-blacklist-usages.sh \
# 	$TOOLS_DIR/bad-sources-flash.txt \
# 	$TOOLS_DIR/bad-symbols-flash.txt \
# 	$TOOLS_DIR/good-sources.txt \
# 	$TOOLS_DIR/good-symbols-flash.txt
# exit

$TOOLS_DIR/find-blacklist-usages.sh \
	$BAD_SOURCES \
	$BAD_SYMBOLS \
	$GOOD_SOURCES \
	$GOOD_SYMBOLS
