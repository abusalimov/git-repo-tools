set -e

TOOLS_DIR=$(dirname $0)
MIGR_DIR=~/git-svn-migration

# export TMPDIR=$TMPDIR/grt-fix.sr6a
export TMPDIR=$(mktemp -d --tmpdir grt-fix.XXXX)
trap "rm -rf $TMPDIR" EXIT

TMP_FILE=$TMPDIR/tmp

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


function indent_i2t2() { sed -re $'s/^ {1,1}(\t+)/\\1/g; :a;s/^(\t*) {2}/\\1\t/;ta'; }
function indent_i3t3() { sed -re $'s/^ {1,2}(\t+)/\\1/g; :a;s/^(\t*) {3}/\\1\t/;ta'; }
function indent_i4t4() { sed -re $'s/^ {1,3}(\t+)/\\1/g; :a;s/^(\t*) {4}/\\1\t/;ta'; }
function indent_i4t8() { sed -re $'s/^ {1,7}(\t+)/\\1/g; :a;s/^(\t*) {8}/\\1\t/;ta; s/^(\t+)/\\1\\1/; s/^(\t*) {4}/\\1\t/'; }
function indent_i8t8() { sed -re $'s/^ {1,7}(\t+)/\\1/g; :a;s/^(\t*) {8}/\\1\t/;ta; s/^(\t*) {4}/\\1\t/'; }

function indent_astyle() { astyle --options=none --mode=c -c -o -O -T4 -M8 -w -z2; }
# function indent_astyle() { uncrustify -l c -c /tmp/grt-fix.yLGT/grt-fix.sr6a/call_Uncrustify.cfg | indent_i8t8; }

function indent_fix() {
	cat > $TMP_FILE-orig

	< $TMP_FILE-orig  perl_sed \
		's#(^[^\S\n]+)?+(?:(/\*.*?\*/|//(?:[^\\]|[^\n][\n]?)*?\n)|("(\\.|[^"\\])*"|'"'"'(\\.|[^'"'"'\\])*'"'"'|.[^/"'"'"'\\]*?))#
			defined $3 ? $3 : defined $1 ? ($& =~ s/^[^\S\n]+(.*)$/\1/mgr) : $& #mgse;' \
		> $TMP_FILE-no-indent
	< $TMP_FILE-orig  perl_sed \
		's#(^[^\S\n]+)?+(?:(/\*.*?\*/|//(?:[^\\]|[^\n][\n]?)*?\n)|("(\\.|[^"\\])*"|'"'"'(\\.|[^'"'"'\\])*'"'"'|.[^/"'"'"'\\]*?))#
			(defined $1 || defined $3) ? $& : "\n" x ($& =~ tr/\n//) #mgse;' \
		> $TMP_FILE-no-comments
	< $TMP_FILE-no-comments  indent_astyle                 > $TMP_FILE-astyle
	< $TMP_FILE-astyle       perl_sed 's/\{(?=[^\n]++(?<!\\)\n)([^{}]+)(?<!\\)(?<!#else)(?<!#elif)(?<!#endif)\n[^\S\n]*\}/{\1 }/smg' > $TMP_FILE-astyle-xxx
	< $TMP_FILE-astyle-xxx   perl_sed 's/^(\s*+).*$/\1/mg' > $TMP_FILE-astyle-indent

	if [[ $(wc -l < $TMP_FILE-astyle-indent) == $(wc -l < $TMP_FILE-no-indent) ]]; then
		paste -d'\0' $TMP_FILE-astyle-indent $TMP_FILE-no-indent | perl_sed 's/^(\t+)\*\//\*\/\1/m' | sed -re $'s/[ \t]*$//'
	else
		>&2 echo "$f 	$(wc -l < $TMP_FILE-astyle-indent)	$(wc -l < $TMP_FILE-no-indent)"
		< $TMP_FILE-orig  indent_astyle
		# touch $TMP_FILE-touch
		# while [ -f $TMP_FILE-touch ]; do
		# 	sleep 0.1
		# done
	fi
}

	# >&2 echo "$f"
	# if [[ $f == "./src/net/ipv4/tftp.c/1250168092-588002148ffa7484d19bd3691ac84d11e460e015" ]]; then
	# 	touch $TMP_FILE-touch
	# fi
	# while [ -f $TMP_FILE-touch ]; do
	# 	sleep 0.1
	# done

#fix sed -re 's/\r//g' -- .
# fix indent_i4t4 \
# 	-- $(find . -type f -path '*.[ch]/*-????????????????????????????????????????' \
# 			| grep -vf $BAD_SOURCES | grep -v lwip)
# fix -v indent_fix \
# 	-- $(find . -type f -path '*.[ch]/*-????????????????????????????????????????' \
# 			| grep -vf $BAD_SOURCES | grep -v lwip)

# function strip_trailing_whitespaces() { sed -re $'s/[ \t\r]*$//' | sed -e '/.$/a\'; }
# fix strip_trailing_whitespaces -- .

# indent_kinds=(i4t4 i8t8 i4t8 i2t2 i3t3)
# declare -A indent_log

# function indent_expand() {
# 	local cost_i2t2 cost_i3t3 cost_i4t4 cost_i4t8 cost_i8t8
# 	declare -A costs
# 	local cost_min
# 	local filename result

# 	filename=$(dirname ${f#./})

# 	cat > $TMP_FILE-orig

# 	< $TMP_FILE-orig  perl_sed 's/(\/\*.*?\*\/[^\S\n]*|\/\/\N*)//smg' | strip_trailing_whitespaces > $TMP_FILE-nocomm

# 	function strip_inner_ws() { sed -re ':a;s/^(\s*\S+)\s+/\1/g;ta'; }
# 	function diff_stat() { diff -u0 $@ | pcregrep '^-\t+(?!#|\s)' | wc -l; }

# 	< $TMP_FILE-nocomm  indent_astyle | strip_inner_ws > $TMP_FILE-astyle
# 	for ik in "${indent_kinds[@]}"; do
# 		< $TMP_FILE-nocomm  indent_$ik | strip_inner_ws > $TMP_FILE-$ik
# 		costs[$ik]=$(diff_stat $TMP_FILE-astyle $TMP_FILE-$ik)
# 	done

# 	cost_min=$(IFS=$'\n'; sort -n  <<< "${costs[*]}" | head -n1)

# 	for ik in "${indent_kinds[@]}"; do
# 		if (( costs[$ik] == cost_min )); then
# 			if [[ ${indent_log[$filename]##* } != $ik ]]; then
# 				# if [ -n "${indent_log[$filename]}" ]; then
# 				# 	touch $TMP_FILE-touch
# 				# fi
# 				indent_log[$filename]="${indent_log[$filename]} $ik"
# 				>&2 echo "$f 	${indent_log[$filename]}"
# 				# while [ -f $TMP_FILE-touch ]; do
# 				# 	sleep 0.1
# 				# done
# 			fi
# 			< $TMP_FILE-orig  indent_$ik
# 			break
# 		fi
# 	done
# }
# fix indent_expand \
# 	-- $(find . -type f -path '*.[ch]/*-????????????????????????????????????????' \
# 			| grep -vf $BAD_SOURCES | grep -v lwip)

# declare -A indent_show_once
# function indent_check_log() {
# 	local costs scosts ucosts
# 	local filename log ulog

# 	filename=$(dirname ${f#./})
# 	log=(${indent_log[$filename]})

# 	readarray -t ulog < <(IFS=$'\n'; uniq <<< "${log[*]}")

# 	if [[ ${#ulog[@]} != 1 ]]; then
# 		if [[ -z ${indent_show_once[$filename]} ]]; then
# 			indent_show_once[$filename]=1
# 			(IFS=$'\t'; >&2 echo "$f 	${#log[@]}	${ulog[*]}")
# 		fi
# 	fi

# 	cat
# }
# fix indent_check_log \
# 	-- $(find . -type f -path '*.[ch]/*-????????????????????????????????????????' \
# 			| grep -vf $BAD_SOURCES | grep -v lwip)

fix -v indent_astyle \
	-- \
	src/drivers/terminal/vtparse_table.c \
	src/drivers/char/terminal/vtparse_table.c \
	src/drivers/char/vtparse_table.c \
	src/conio/terminal/vtparse_table.c

