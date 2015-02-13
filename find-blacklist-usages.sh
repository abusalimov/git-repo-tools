#!/bin/bash
#
# dump_dir=/tmp/git-dump; cd $dump_dir
# ./find-blacklist-usages.sh \
#     blacklist-sources.txt \
#     blacklist-symbols.txt \
#     whitelist-sources.txt \
#     whitelist-symbols.txt
#
# See also: tree-dump.sh
#
set -e

export TMPDIR=$(mktemp -d --tmpdir grt-find.XXXX)
trap "rm -rf $TMPDIR" EXIT
echo "$(basename $0): TMPDIR: $TMPDIR"


function file_arg() {
	local var="$1"
	local arg="$2"

	if [[ -f $arg ]]; then
		eval $var="$arg"
	else
		tmp=$(mktemp)
		if cat < "$arg" > "$tmp"; then
			eval $var="$tmp"
		else
			>&2 echo "$var: unable to read file"
			exit 1
		fi
	fi
}

file_arg "BLACKLIST_SOURCES" "$1"; shift
file_arg "BLACKLIST_SYMBOLS" "$1"; shift
file_arg "WHITELIST_SOURCES" "$1"; shift
file_arg "WHITELIST_SYMBOLS" "$1"; shift


blacklist_files=$TMPDIR/files
blacklist_headers=$TMPDIR/headers
blacklist_ctags=$TMPDIR/ctags
blacklist_filenames=$TMPDIR/filenames
tmp_list=$TMPDIR/list


< $BLACKLIST_SOURCES  xargs -L1 basename | egrep '\.h$' | sort -u \
	| egrep -wv 'eth|regs' > $blacklist_headers
echo "$(wc -l < $BLACKLIST_SOURCES) blacklist files" \
	"($(wc -l < $blacklist_headers) headers)"

< $BLACKLIST_SOURCES  xargs -I% find % -type f > $blacklist_files
echo "$(wc -l < $blacklist_files) blacklist file versions"

< $BLACKLIST_SOURCES  xargs -L1 basename | cut -d'.' -f1 | sort -u \
	| grep -wvf $WHITELIST_SYMBOLS > $blacklist_filenames

function run_ctags() {
	local lang="$1"
	local ext="$2"
	local kind="$3"

	ctags -L <(egrep "\.$ext/[0-9a-f]{40}" < $blacklist_files) \
		--language-force=$lang --file-scope=no --c-kinds="$kind" -f - \
		| cut -f1 | sort -u | grep -wvf $WHITELIST_SYMBOLS \
		>> $blacklist_ctags || true
}
> $blacklist_ctags
run_ctags  c    'h'      fd
run_ctags  c    'c'      f
run_ctags  asm  'S|inc'  f
echo "$(wc -l < $blacklist_ctags) identifiers from blacklist files"

git_grep_args=(-i \( \
		-f $BLACKLIST_SYMBOLS \
		-f $blacklist_filenames \
		-f $blacklist_ctags \
		-f $blacklist_headers \)
	--and --not \( \
		-e 'Asynchronous' \
		-e 'asynchronous' \
		-e 'emacs' \
		-e 'xilinx_emaclite' \
		-e 'xemaclite' \
		-e 'HTYPE_HYPERCHANNEL' \
		-e 'HTYPE_FIBRE_CHANNEL' \
		-e 'icmp_receive_packet' \
		-e 'set_mac_address' \
		-e 'set_macaddr' \
		-e 'msg_control' \
		-e 'sk_lock synchronizer' \
		-e 'synchronous token' \
		-e 'Synchronous Idle' \
		-e 'synchronize DDR' \
		-e 'ModViewScrollArea' \
		-e 'device is set to synchronous' \))

find . -type f \
	| fgrep -v -f $blacklist_files -f $WHITELIST_SOURCES \
	| xargs git grep --no-index --name-only \
		"${git_grep_args[@]}" \
	| sort -u > $tmp_list
echo "$(wc -l < $tmp_list) file versions " \
	"($(< $tmp_list xargs -n1 dirname | sort -u | wc -l) files) to analyze"

for f in $(cat $tmp_list); do
	echo
	echo $f
	git grep --no-index --color=always -2 -hp \
		"${git_grep_args[@]}" \
		$f || true
done

