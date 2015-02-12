#!/bin/bash
#
# dump_dir=/tmp/git-dump; cd $dump_dir
# ./fix-and-test.sh
#
# See also: tree-dump.sh
#
set -e

export TMPDIR=$(mktemp -d --tmpdir grt-fix.XXXX)
trap "rm -rf $TMPDIR" EXIT
echo "$(basename $0): TMPDIR: $TMPDIR"

cp -r . $TMPDIR/dump; cd $TMPDIR/dump

TMP_FILE=$TMPDIR/tmp
TOOLS_DIR=$(dirname $0)

function perl_sed() { perl -0777 -pe "$@"; }


BAD_SOURCES=$MIGR_DIR/ovk-files-6.txt
BAD_SYMBOLS=$MIGR_DIR/ovk-bad-ids.txt
GOOD_SOURCES=$MIGR_DIR/ovk-valid-paths.txt
GOOD_SYMBOLS=$MIGR_DIR/ovk-valid-ids.txt


bad_headers=$MIGR_DIR/bad_headers
bad_files=$MIGR_DIR/bad_files
bad_symbols_found=$MIGR_DIR/bad_symbols_found
bad_lines=$MIGR_DIR/bad_lines
bad_filenames=$MIGR_DIR/bad_filenames

blacklist=$MIGR_DIR/blacklist
affected_sources=$MIGR_DIR/affected_sources


function rm_files() {
	local args=()
	for f; do
		args+=(-o -path "./$f")
	done

	for f in $(find . -depth -type d -\( -false "${args[@]}" -\)); do
		rm -r "$f"
	done
}
rm_files \
	\*.bin \
	\*.pyc \
	\*.d \
	\*.o \
	test.txt \
	test_svn_ticket.txt

function rm_if() {
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
	echo rm_if
	echo "$script" "${args[@]}"
	echo

	local files="$@"
	if [[ -z "$files" ]]; then
		>&2 echo "No files specified!"
		exit 1
	fi

	for f in $(find $files -type f); do
		if "$script" "${args[@]}" < $f > /dev/null; then
			rm -r "$f"
		fi
	done
}

# < $BAD_SOURCES  xargs -L1 basename | egrep '\.h$' | sort -u \
# 	| egrep -wv 'eth|regs' > $bad_headers
# < $BAD_SOURCES  xargs -I% find % -type f > $bad_files
# < $BAD_SOURCES  xargs -L1 basename | cut -d'.' -f1 | sort -u \
# 	| grep -wvf $GOOD_SYMBOLS > $bad_filenames


# function run_ctags() {
# 	local lang="$1"; local ext="$2"; local kind="$3"
# 	ctags -L <(egrep "\.$ext/[0-9a-f]{40}$" < $bad_files) \
# 		--language-force=$lang --file-scope=no --c-kinds="$kind" -f - \
# 		| cut -f1 | sort -u | grep -wvf $GOOD_SYMBOLS || true
# }
# > $bad_symbols_found
# run_ctags  c    'h'      fd  >> $bad_symbols_found
# run_ctags  c    'c'      f   >> $bad_symbols_found
# run_ctags  asm  'S|inc'  f   >> $bad_symbols_found

# cat  $BAD_SYMBOLS  $bad_symbols_found  $bad_headers  > $bad_lines
# cat  $bad_symbols_found  $bad_filenames  > $blacklist

# find . -type f \
# 	| fgrep -v -f $bad_files -f $GOOD_SOURCES \
# 	| egrep '[Sch]/[0-9a-f]{40}$' \
# 	| xargs git grep --no-index --name-only -w -f $bad_lines \
# 	| sort -u > $affected_sources



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
					git diff --no-index --color=always $f $TMP_FILE | tail -n +5 || true
				else
					echo $f
				fi
			fi

			cat < $TMP_FILE > $f
		fi
	done
}

function strip_trailing_whitespaces() { sed -re $'s/[ \t\r]*$//' | sed -e '/.$/a\'; }
fix strip_trailing_whitespaces -- .

function indent_astyle() { astyle --options=none -t4 -M8 -z2; }
function indent_i2t2() { sed -re $'s/^ {1,1}(\t+)/\\1/g; :a;s/^(\t*) {2}/\\1\t/;ta'; }
function indent_i3t3() { sed -re $'s/^ {1,2}(\t+)/\\1/g; :a;s/^(\t*) {3}/\\1\t/;ta'; }
function indent_i4t4() { sed -re $'s/^ {1,3}(\t+)/\\1/g; :a;s/^(\t*) {4}/\\1\t/;ta'; }
function indent_i4t8() { sed -re $'s/^ {1,7}(\t+)/\\1/g; :a;s/^(\t*) {8}/\\1\t/;ta; s/^(\t+)/\\1\\1/; s/^(\t*) {4}/\\1\t/'; }
function indent_i8t8() { sed -re $'s/^ {1,7}(\t+)/\\1/g; :a;s/^(\t*) {8}/\\1\t/;ta; s/^(\t*) {4}/\\1\t/'; }

declare -A indent_log

function indent_expand() {
	local cost_i2t2 cost_i3t3 cost_i4t4 cost_i4t8 cost_i8t8
	local costs scosts cost_min
	local filename result

	filename=$(dirname ${f#./})

	cat > $TMP_FILE-orig

	< $TMP_FILE-orig  perl_sed 's/(\/\*.*?\*\/[^\S\n]*|\/\/\N*)//smg' | strip_trailing_whitespaces > $TMP_FILE-nocomm

	function strip_inner_ws() { sed -re ':a;s/^(\s*\S+)\s+/\1/g;ta'; }
	< $TMP_FILE-nocomm  indent_astyle | strip_inner_ws > $TMP_FILE-astyle
	< $TMP_FILE-nocomm  indent_i2t2 | strip_inner_ws > $TMP_FILE-i2t2
	< $TMP_FILE-nocomm  indent_i3t3 | strip_inner_ws > $TMP_FILE-i3t3
	< $TMP_FILE-nocomm  indent_i4t4 | strip_inner_ws > $TMP_FILE-i4t4
	< $TMP_FILE-nocomm  indent_i4t8 | strip_inner_ws > $TMP_FILE-i4t8
	< $TMP_FILE-nocomm  indent_i8t8 | strip_inner_ws > $TMP_FILE-i8t8

	function diff_stat() { diff -u0 $@ | pcregrep '^-\t+(?!#|\s)' | wc -l; }
	cost_i2t2=$(diff_stat $TMP_FILE-astyle $TMP_FILE-i2t2)
	cost_i3t3=$(diff_stat $TMP_FILE-astyle $TMP_FILE-i3t3)
	cost_i4t4=$(diff_stat $TMP_FILE-astyle $TMP_FILE-i4t4)
	cost_i4t8=$(diff_stat $TMP_FILE-astyle $TMP_FILE-i4t8)
	cost_i8t8=$(diff_stat $TMP_FILE-astyle $TMP_FILE-i8t8)

	costs=( \
		$cost_i2t2 \
		$cost_i3t3 \
		$cost_i4t4 \
		$cost_i4t8 \
		$cost_i8t8 )

	readarray -t scosts < <(IFS=$'\n'; sort -n  <<< "${costs[*]}")
	cost_min=${scosts[0]}

	  if (( cost_min == cost_i4t4 )); then  < $TMP_FILE-orig  indent_i4t4; result="i4t4"; fi
	elif (( cost_min == cost_i8t8 )); then  < $TMP_FILE-orig  indent_i8t8; result="i8t8"; fi
	elif (( cost_min == cost_i4t8 )); then  < $TMP_FILE-orig  indent_i4t8; result="i4t8"; fi
	elif (( cost_min == cost_i2t2 )); then  < $TMP_FILE-orig  indent_i2t2; result="i2t2"; fi
	elif (( cost_min == cost_i3t3 )); then  < $TMP_FILE-orig  indent_i3t3; result="i3t3"; fi

	indent_log[$filename]="${indent_log[$filename]} $result"
}
fix indent_expand \
	-- $(find . -type f -path '*.[ch]/*-????????????????????????????????????????' \
			| grep -vf $BAD_SOURCES | grep -v lwip)

function indent_check_log() {
	local costs scosts ucosts
	local filename log ulog

	filename=$(dirname ${f#./})
	log=(${indent_log[$filename]})

	readarray -t ulog < <(IFS=$'\n'; sort -u  <<< "${log[*]}")
	if [[ ${#ulog[@]} != 1 ]]; then
		(IFS=$'\t'; >&2 echo "$f 	${log[*]}")
	fi

	cat
}
fix indent_check_log \
	-- $(find . -type f -path '*.[ch]/*-????????????????????????????????????????' \
			| grep -vf $BAD_SOURCES | grep -v lwip)

fix indent_astyle \
	-- \
	src/drivers/terminal/vtparse_table.c \
	src/drivers/char/terminal/vtparse_table.c \
	src/drivers/char/vtparse_table.c \
	src/conio/terminal/vtparse_table.c

fix perl_sed 's/<target[^<>]*?ovk.*?\/target>\n?//smg;' \
	-- .cproject

fix $TOOLS_DIR/cleanup-json.py \
	-- \
	.config \
	.config.default \
	.config.in \
	config \
	config.default \
	scripts/.config.in

fix perl_sed 's/\bovk_(?=monitor(_r[ao]m)?\b)//g;' \
	-- \
	.config \
	.config.default \
	.config.in \
	build.sh \
	config \
	config.default \
	makefile \
	OVK-configure.py \
	scripts/.config.in \
	scripts/autoconf \
	scripts/autoconf.default \
	scripts/autoconf.in \
	scripts/autoconf_mb \
	scripts/md5_checksummer/Makefile

fix perl_sed '
		s/"ovk> "/"monitor> "/g;
		s/"OVK\s+Configurator"/"Monitor Configurator"/g;
		s/Welcome to OVK shell/Welcome to Monitor shell/g;
	' -- \
	.config \
	.config.default \
	.config.in \
	config \
	config.default \
	scripts/.config.in \
	scripts/autoconf.h.in \
	scripts/autoconf.h \
	scripts/config.h \
	src/conio/shell.c \
	conf/ugly.conf \
	templates/microblaze/embox-usr.conf \
	templates/microblaze/options-shell.conf \
	templates/microblaze/ugly.conf \
	templates/microblaze/usr.conf \
	templates/sparc/ugly.conf

fix -v perl_sed '
		s/\b(MONITOR_DRIVERS?)_TERCOM(_AMBA_PNP)\b/\1\2/g;
		s/\b(MONITOR_DRIVERS?_AMBA_PNP)\b(\S*[^\S\n]{2,})(?!$)/\1\2       /g;
	' -- \
	.config.default \
	.config.in \
	scripts/.config.in \
	scripts/autoconf \
	scripts/autoconf.default \
	scripts/autoconf.h \
	scripts/autoconf.h.in \
	scripts/autoconf.in \
	scripts/autoconf_mb \
	src/drivers/amba_pnp/amba_pnp.mmod \
	src/drivers/amba_pnp/Makefile \
	src/drivers/makefile

fix $TOOLS_DIR/cleanup-json.py \
	--words-file $blacklist \
	-- \
	.config \
	.config.default \
	.config.in \
	config \
	config.default \
	scripts/.config.in

fix $TOOLS_DIR/cleanup-code.sh \
	--directives 'tercom_pnp_devices_table' \
	--functions 'tercom_pnp_devices_table' \
	-- \
	src/user/lspnp/lspnp.c \
	src/cmds/lspnp/lspnp.c

fix $TOOLS_DIR/cleanup-code.sh \
	--directives 'RELEASEOVK(_TRG)?' \
	-- \
	conf/ugly.conf \
	templates/microblaze/ugly.conf \
	templates/sparc/ugly.conf

fix -v pcregrep -Mv '(?xs)
		( ^if(eq|def)\b \N*?
			\b(RELEASEOVK(_TRG)? | MONITOR_DRIVERS?_TERCOM_OVK_\w+)\b
		  .*?
		  ^endif
		| \b(link.*?tmp)\b )' \
	-- \
	makefile \
	Makefile \
	src/drivers/makefile

fix pcregrep -wv 'RELEASE_?OVK(_TRG)?' \
	-- \
	scripts/autoconf.default \
	scripts/autoconf.h.in \
	scripts/autoconf.in \
	scripts/autoconf_mb \
	templates/microblaze/ugly.conf \
	templates/sparc/ugly.conf

fix pcregrep -v '(?x)
		  AURCTRL
		| AURORA_LINKS
		| BRDSTATS
		| CHANWATCH
		| DATA_?MANAGER
		| DMRESET
		| EMACSTAT
		| INIT_SYNCHRONIZE
		| IO_CTRL
		| IOBOARD
		| MDIO
		| PWRCTRL
		| SGCTRL
		| SYNCHRO
		| SYNCHRO_MEMORY
		| SYNCHRONIZATION
		| TEST_LOOPBACK
		| TEST_STATISTICS
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
	templates/icebrick/drivers.conf \
	templates/icebrick/embox-drivers.conf \
	templates/icebrick/tests.conf \
	templates/icebrick/usr.conf \
	templates/microblaze/embox-usr.conf \
	templates/microblaze/tests.conf \
	templates/microblaze/usr.conf \
	templates/sparc/tests.conf \
	templates/sparc/usr.conf

fix perl_sed '
		s/
			(?: ((?<![=\s]))? [^\S\n]* (\\)? \n )?
			(?: ^\s* \#)? ([^\S\n])* (?: (\S)*? (?<![,()\$\\]) (?(4)(?<!=)) )? \b (
			  tercom
			| ovk
			| ovk_align_(entry|handler)
			| (full|trace?|addons)_align
			| align
			| aurctrl
			| aurora_control
			| brdstats
			| board_statistic
			| chanwatch
			| cpu_rx_errs_cmd
			| CpuRxErrsCmd
			| dmreset
			| emac
			| emacstat
			| eth
			| ovk_eth
			| io_?board
			| irq_majoritar
			| mdio
			| mac_io
			| pwrctrl
			| sgctrl
			| synchro
			| synchro_dma
			| synchro_trac
			| synchro_controller
			| statistics
			| timeslots_manager
			| uart_align
			| (?-x:(?<!in this ))version
			| version_module
			| (test_)?(
				  aurora_links
				| data_manager
				| data_manager_dma
				| io_ctrl
				| loopback
				| synchro_memory
				| synchronisation
				| synchronization
			) ) \b (?: (?![,()\$\\]) \S* )?
			(?(1) (?(2)| [^\S\n]* \\$ ))?
			(?(3)| [^\S\n]*+ (?! \\ \n))?
		//xmg;

		s/.*\+=\s*?\n//mg;
		s/(.+)\s*?:=\s*?\$\(filter-out,\$\(\1\)\)\s*?\n//mg;
	' -- \
	src/drivers/subdirs \
	src/drivers/makefile \
	src/tests/subdirs \
	src/user/subdirs \
	src/architectures/sparc/makefile \
	src/arch/sparc/makefile \
	src/arch/sparc/Makefile \
	src/arch/sparc-obsolete/Makefile \
	src/kernel/makefile \
	src/kernel/Makefile \
	src/user/makefile \
	src/user/Makefile \
	src/tests/makefile \
	src/tests/Makefile \
	src/testsuites/Makefile \
	src/drivers/amba_pnp/makefile \
	src/drivers/amba_pnp/Makefile \
	src/drivers/ambapp/Makefile \
	src/drivers/amba_pnp/gaisler/uart/makefile \
	src/drivers/gaisler/uart/makefile \
	src/kernel/kernel.mmod \
	src/arch/sparc/arch_sparc.mmod \
	src/drivers/amba_pnp/amba_pnp.mmod \
	src/net/net.mmod \
	src/testsuites/express_tests.mmod

fix -v pcregrep -wv 'OVK_ALIGN' \
	-- src/arch/sparc/Makefile
fix -v pcregrep -v '(?x)
		\b CORRECT_(
		  VERSION_MODULE
		| DATA_MANAGER
		| AURORA_CONTROLLER
		| BOARD_MANAGER
		| SYNCHRO_MEMORY
		| IO_BOARD
		| CPU_SYNCHRO_CONTROLLER
		| STATE_CONTROLLER )
	' -- src/tests/test_addons_availability.h

fix -v perl_sed '
		s/
			( ^\t else \N*? \n
			  \N*? echo \s " ) \N*? \b(?:releaseovk)\b \N*? (" .*?
				^\t\s*) cat (\N*?) \| .*? > \s? (\N*? \n
				^\t\s*) cat (\N*?) \| .*? > \s? (\N*? \n)
			(?=^\t fi;)
		/\1Building default configuration (try '"'"'make x[menu]config'"'"')\2cp\3\4cp\5\6/xms;

		s/
			(?: ^\# .*? \n )*
			^( \b(?:ROOT_DIR)\b \s*?(\s)? ) (?: \s (?!:))? :?= .*? \b(ovk|pwd)\b .*? $
			(\n ^\# .*? $)*
		/\1:=\2\$(CURDIR)/xm;
	' -- \
	makefile \
	Makefile

fix pcregrep -Mv '(^(#\N*)?\n)*.*?\b(ovk)\b' \
	-- mk/main.mk

fix pcregrep -Mv '(?x)
		^(?!\t) ((?!\.PHONY).)*? \b(releaseovk)\b .* \n
		(^\t .* \n)* (^\n (?=^\n))*
	' -- \
	src/makefile \
	scripts/build.mk

fix perl_sed 's/((?:\t|.*?\.PHONY).*?)\s*(?:--)?\b(releaseovk)\b/\1/g;' \
	-- \
	makefile \
	src/makefile \
	scripts/build.mk

fix pcregrep -Mvi '(^$\n// )?tercom' \
	-- \
	src/drivers/pnp_devices_table.inc \
	src/drivers/pnp_vendors_table.inc \
	src/drivers/amba_pnp/pnp_devices_table.inc \
	src/drivers/amba_pnp/pnp_vendors_table.inc \
	src/user/lspnp/pnp_vendors_table.inc \
	src/cmds/lspnp/pnp_vendors_table.inc \
	conf/drivers.conf \
	scripts/autoconf \
	scripts/autoconf.default \
	scripts/autoconf.in \
	scripts/autoconf_mb \
	scripts/autoconf.h.in \
	conf/usr.conf \
	templates/microblaze/drivers.conf \
	templates/microblaze/usr.conf \
	templates/sparc/drivers.conf \
	templates/sparc/usr.conf

fix perl_sed 's/(HOSTNAME\s+)"ovk"/\1"monitor"/g' \
	-- \
	include/net/bootp.h \
	src/include/net/bootp.h

fix perl_sed 's/ generated by OVK-configure\.py/: auto-generated by configure.py/g' \
	-- \
	OVK-configure.py \
	scripts/config-builder_1_0/OVK_configure_gen.py \
	scripts/OVK-configure.py \
	scripts/OVK_configure_gen.py \
	src/conio/shell.inc \
	src/conio/tests.inc \
	src/conio/users.inc \
	src/tests/tests_table.inc

fix perl_sed '
		s/OVK project\\nFault-tolerant Computing Complex\\n(?:(.*)At-Software, )?/\1/g;
		s/OVK[_\-](?=configure)//g;
		s/(?i)OVK(?= configur)/Monitor/g;
		s/ and cmd != "mdio"//g;
   ' -- \
	Makefile \
	makefile \
	OVK-configure.py \
	scripts/config-builder_1_0/OVK-configure.py \
	scripts/config-builder_1_0/OVK_configure_gen.py \
	scripts/config-builder_1_0/OVK_configure_gui.py \
	scripts/ConfigBuilder/TkGui/confgui.py \
	scripts/OVK-configure.py \
	scripts/OVK_configure_gen.py \
	scripts/OVK_configure_gui.py

fix pcregrep -v 'releaseovk(?!",)|(?<!,u.link_)(?<!\)_)ovk_?rom' \
	-- \
	scripts/checksum.py \
	scripts/config-builder_1_0/checksum.py \
	scripts/config-builder_2_0/mcglobals.py \
	scripts/ConfigBuilder/Misc/checksum.py \
	scripts/ConfigBuilder/Parser/mcglobals.py

fix perl_sed 's/\bOVK monitor\b/Monitor/g' \
	-- \
	scripts/checksum.py \
	scripts/conf_tab.py \
	scripts/config-builder_1_0/checksum.py \
	scripts/config-builder_1_0/conf_tab.py \
	scripts/config-builder_1_0/misc.py \
	scripts/config-builder_1_0/OVK-configure.py \
	scripts/config-builder_1_0/OVK_configure_gen.py \
	scripts/config-builder_1_0/OVK_configure_gui.py \
	scripts/ConfigBuilder/CodeGen/confgen.py \
	scripts/ConfigBuilder/Misc/checksum.py \
	scripts/ConfigBuilder/Misc/misc.py \
	scripts/ConfigBuilder/TkGui/confgen.py \
	scripts/ConfigBuilder/TkGui/confgui.py \
	scripts/ConfigBuilder/TkGui/confmain.py \
	scripts/ConfigBuilder/TkGui/conftab.py \
	scripts/misc.py \
	scripts/OVK-configure.py \
	scripts/OVK_configure_gen.py \
	scripts/OVK_configure_gui.py

fix perl_sed '
		s/
			,\n ^\s* \[.*?
			  \b(aurctrl|brdstats|emac|ethsend|ethlisten|ethtest
			  	|ioboardwr|ioboardrd|mdio|mdiow|mdior|pwrctrl|sgctrl|synchro
			  	|test_io_ctrl|test_data_manager|test_synchronization)\b
			.*?\]
		//xmg;
	' -- \
	OVK-configure.py

fix pcregrep -Mv '(^\s*)if.*?\b(ovk|version_module)\b(.|\n)*?(\n\1\s+.*)+' \
	-- scripts/OVK-configure.py
fix pcregrep -wv 'ovk' \
	-- OVK-configure.py

fix perl_sed '
		s/\bovk(?=_tab\b)/monitor/g;
	    s/if mdef not in \(.*?TERCOM_OVK.*?\)/if mdef != "MONITOR_DRIVERS_GAISLER"/msg;
	' -- \
	OVK-configure.py \
	scripts/OVK-configure.py

fix perl_sed 's/"releaseovk",\s*//g' \
	-- scripts/checksum.py
fix perl_sed 's/,u.link_ovkrom\.S.//g' \
	-- scripts/config-builder_2_0/mcglobals.py

fix pcregrep -wv '(ovk|hell)' \
	-- scripts/md5_checksummer/Makefile
fix perl_sed '
		s/_ovk_rom//g;
	    s/gcc (?=\$\(INCLUDE_DIR\))/gcc -I/g;
   ' -- scripts/md5_checksummer/Makefile

fix egrep -ivf $bad_symbols_found \
	-e '(io|cpu).?board|data.?manager' \
	-- \
	src/conio/shell.inc \
	src/drivers/amba_pnp/pnp_devices_table.inc \
	src/drivers/amba_pnp/pnp_vendors_table.inc \
	src/drivers/pnp_devices_table.inc \
	src/drivers/pnp_vendors_table.inc \
	src/tests/tests_table.inc

fix perl_sed 's/,(?=\s*\Z)//m' \
	-- \
	src/user/lspnp/pnp_vendors_table.inc \
	src/conio/shell.inc \
	src/drivers/amba_pnp/pnp_devices_table.inc \
	src/drivers/amba_pnp/pnp_vendors_table.inc \
	src/drivers/pnp_devices_table.inc \
	src/drivers/pnp_vendors_table.inc \
	src/tests/tests_table.inc

function perl_fix_trap_table() {
	perl_sed '
		s/
			(?-x:^(\s*)BAD_TRAP; BAD_TRAP; BAD_TRAP; BAD_TRAP;(\s*)! 6C - 6F undefined)
			.*
			(?-x:^\s*BAD_TRAP; BAD_TRAP; BAD_TRAP; BAD_TRAP;\s*! 74 - 77 undefined)

/\1BAD_TRAP; BAD_TRAP; BAD_TRAP; BAD_TRAP;\2! 6C - 6F undefined
\1BAD_TRAP; BAD_TRAP; BAD_TRAP; BAD_TRAP;\2! 70 - 73 undefined
\1BAD_TRAP; BAD_TRAP; BAD_TRAP; BAD_TRAP;\2! 74 - 77 undefined/xms;

		s/TRAP\(full_align_irq\);/TRAP_ENTRY_INTERRUPT;/g;
		s/BAD_TRAP;(\s*)!(\s*)TRAP\((full|trace?)_align_(trap|irq)\);/BAD_TRAP;/g;
		s/TRAP\((full|trace?)_align_(trap|irq)\);?\s*!\s*(?=(SOFT|BAD)_TRAP)//g;
		s/TRAP\((full|trace?)_align_(trap|irq)\);\s*(SOFT|BAD)_TRAP;/\3_TRAP; \3_TRAP;/g;
		s/TRAP\((full|trace?)_align_(trap|irq)\);/SOFT_TRAP;/g;
		s/TRAP\(trap_dispatcher\);           !/TRAP(trap_dispatcher);        !/g;' \
	| perl -MText::Tabs -n -e '$tabstop = 4; print expand $_'
}

fix perl_fix_trap_table \
	-- \
	src/kernel/traps.inc \
	src/architectures/sparc/traps.inc \
	src/arch/sparc/traps.inc \
	src/arch/sparc-obsolete/traps.inc \
	src/arch/sparc/kernel/trap_table.inc \
	src/arch/sparc-experimental/kernel/trap_table.inc \
	src/arch/sparc-experimental/trap_table.inc

fix pcregrep -Mv '(?s)\bfull_align_trap\b.*?\bRESTORE_ALL\b\n' \
	-- src/arch/sparc/entry.S

fix pcregrep -Mv '(?s)\bfull_align_trap\b.*?\brett\b.*?\n' \
	-- src/architectures/sparc/traps.S

fix pcregrep -Mv '^(\s*\. = ALIGN.*?)?\n\s*\*\(\.full_align_section\)' \
	-- \
	scripts/link_ovkrom.S \
	scripts/linker/embox.lds.S \
	scripts/linker/link_ovkrom.S \
	scripts/linker/linkram \
	scripts/linker/linkrom \
	scripts/linker/linksim \
	scripts/linkram \
	scripts/linkrom \
	scripts/linksim \
	src/arch/microblaze/embox.lds

fix grep -wv 'ovk_align' \
	-- src/arch/sparc-experimental/embox.lds.S

fix pcregrep -Mv '(?s)\bVENDOR_ID_TEPKOM\b.*?}' \
	-- src/drivers/plug_and_play.c

fix egrep -wv 'RELEASEOVK_TRG|init_mdio_channels' \
	-- src/net/ipconfig.c

fix $TOOLS_DIR/cleanup-code.sh \
	--directives '
		  SIMULATION_TRG
		| SIMULATE_TRG
		| RELEASEOVK_TRG
	' -- \
	src/arch/boot.S \
	src/arch/microblaze/boot.S \
	src/arch/sparc-obsolete/boot.S \
	src/arch/sparc-obsolete/Copy_boot.S \
	src/arch/sparc/boot.S \
	src/arch/sparc/Copy_boot.S \
	src/arch1/boot.S \
	src/architectures/boot.S \
	src/architectures/sparc/boot.S \
	src/kernel/boot.S \
	src/user/shell/start_script.inc \
	src/cmds/shell/start_script.inc \
	src/conio/start_script.inc

fix -v pcregrep -v 'IO_BOARD_STATUS_WRITE_CONST' \
	-- \
	src/arch/sparc-obsolete/Copy_boot.S \
	src/arch/sparc/Copy_boot.S

fix -v pcregrep -v '_SYNCHRONIZE' \
	-- \
	src/include/embox/runlevel.h \
	src/include/kernel/init.h

fix -v $TOOLS_DIR/cleanup-code.sh \
	--functions 'dispatch_full_align_trap' \
	-- src/kernel/irq.c

fix -v $TOOLS_DIR/cleanup-code.sh \
	--functions 'irq_ctrl_align' \
	-- src/drivers/amba_pnp/gaisler/irq_ctrl/irq_ctrl.c
fix -v pcregrep -v 'full_align_irq_mask' \
	-- src/drivers/amba_pnp/gaisler/irq_ctrl/irq_ctrl.c

fix $TOOLS_DIR/cleanup-code.sh \
	--directives '0' \
	-- \
	src/tests/ifconfig/ifconfig.c \
	src/user/ifconfig/ifconfig.c

fix perl_sed 's/ethtest_help.inc/ifconfig_help.inc/' \
	-- \
	src/tests/ifconfig/ifconfig_help.inc

# # XXX
# rm_if grep 'data_manager' \
# 	-- \
# 	src/tests/ifconfig/ifconfig.c \
# 	src/user/ifconfig/ifconfig.c

fix $TOOLS_DIR/cleanup-code.sh \
	--functions '
		  eth_show_interface(_by_name)?
		| eth_show_all_interfaces
		| (if|inet_)dev_show(_all)?_info
		| data_manager_\w+
		| set_mac
	' -- \
	include/net/eth.h \
	include/net/if_device.h \
	include/net/inetdevice.h \
	src/net/core/devinet.c \
	src/net/core/if_device.c \
	src/net/core/if_device.h \
	src/net/eth.c \
	src/net/eth.h \
	src/net/ethernet/eth.c \
	src/net/ethernet/eth.h \
	src/net/if_device.c \
	src/net/if_device.h \
	src/net/ipconfig.c

fix perl_sed 's/eth_dev_(open|close)/\/\/ eth_dev_\1/g' \
	-- src/net/ethernet/eth.c

fix $TOOLS_DIR/cleanup-code.sh \
	--directives '\w*(?i:tercom|tepkom|ovk|it_s_not_needed_anymore)\w*' \
	--functions '
		  test_fifo
		| version_module_init
		| synchro_state_init
		| synchro_memory_init
		| synchro_dma_init
		| synchro_state_synchronize
		| synchro_trac_init
		| ovk_eth_init
		| emac_init
		| mdio_init
		| data_manager_init
		| irq_majoritar_init
		| init_chanwatch
		| enable_chanwatch
		| disable_chanwatch
		| close_chanwatch
		| mac_io_init
		| data_manager_channels_init
		| timeslots_manager_init
	' -- \
	src/arch/sparc/init.c \
	src/kernel/init.c \
	src/kernel/main.c

fix pcregrep -Mv '\s*#\s*if\b.*?\n\s*#\s*endif\b' \
	-- \
	src/arch/sparc/init.c \
	src/kernel/init.c \
	src/kernel/main.c

fix $TOOLS_DIR/cleanup-code.sh \
	--functions 'uart_align' \
	-- \
	src/drivers/amba_pnp/gaisler/uart/uart.c \
	src/drivers/gaisler/uart/uart.c \
	src/drivers/uart.c


fix perl_sed '
		s/\bOVK_REGLOAD\b/REG_LOAD/g;
		s/\bOVK_REGSAVE\b/REG_STORE/g;
		s/\bOVK_REGORIN\b/REG_ORIN/g;
		s/\bOVK_REGANDIN\b/REG_ANDIN/g;
	' -- $(cat $affected_sources)

fix $TOOLS_DIR/cleanup-code.sh \
	--directives-file $bad_headers \
	--directives \
		'\w*(?i:tercom|tepkom|ovk)\w*' \
	-- $(cat $affected_sources) \
	src/user/ifconfig/ifconfig.c


fix perl_sed 's/(\/\/)?\/\*\*\n(\/\/)? \* for ovk system\n(\/\/)? \*\///g' \
	-- \
	src/drivers/amba_pnp/gaisler/timer/timers.c \
	src/drivers/gaisler/timer/timers.c \
	src/drivers/timers.c

fix pcregrep -Mv '(?s)//======+.*?//======+\n//(\n^$)+' \
	-- src/kernel/mem_traps.c

fix grep -v '// max devices in OVK' \
	-- \
	include/drivers/amba_pnp.h \
	include/drivers/amba_pnp/amba_pnp.h \
	src/drivers/amba_pnp/amba_pnp.h \
	src/include/drivers/amba_pnp.h


$TOOLS_DIR/find-blacklist-usages.sh \
	$BAD_SOURCES \
	$BAD_SYMBOLS \
	$GOOD_SOURCES \
	$GOOD_SYMBOLS

