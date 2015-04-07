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


BAD_SOURCES=$TOOLS_DIR/bad-sources.txt
BAD_SYMBOLS=$TOOLS_DIR/bad-symbols.txt
GOOD_SOURCES=$TOOLS_DIR/good-sources.txt
GOOD_SYMBOLS=$TOOLS_DIR/good-symbols.txt

blacklist=$TOOLS_DIR/blacklist
bad_headers=$TOOLS_DIR/bad_headers
bad_symbols_found=$TOOLS_DIR/bad_symbols_found
bad_lines=$TOOLS_DIR/bad_lines
bad_filenames=$TOOLS_DIR/bad_filenames


# bad_files=$TMP_FILE-bad
# affected_sources=$TMP_FILE-affected
bad_files=$MIGR_DIR/bad_files
affected_sources=$MIGR_DIR/affected_sources


# # < $BAD_SOURCES  xargs -L1 basename | egrep '\.h$' | sort -u \
# # 	| egrep -wv 'eth|regs' > $bad_headers
# < $BAD_SOURCES  xargs -I% find % -type f > $bad_files
# # < $BAD_SOURCES  xargs -L1 basename | cut -d'.' -f1 | sort -u \
# # 	| grep -wvf $GOOD_SYMBOLS > $bad_filenames


# function run_ctags() {
# 	local lang="$1"; local ext="$2"; local kind="$3"
# 	ctags -L <(egrep "\.$ext/[0-9]+-[0-9a-f]{40}$" < $bad_files) \
# 		--language-force=$lang --file-scope=no --c-kinds="$kind" -f - \
# 		| cut -f1 | sort -u | grep -wvf $GOOD_SYMBOLS || true
# }
# > $bad_symbols_found
# run_ctags  c    'h'      fd  >> $bad_symbols_found
# run_ctags  c    'c'      f   >> $bad_symbols_found
# run_ctags  asm  'S|inc'  f   >> $bad_symbols_found

# # cat  $BAD_SYMBOLS  $bad_symbols_found  $bad_headers  > $bad_lines
# # cat  $bad_symbols_found  $bad_filenames  > $blacklist

# find . -type f \
# 	| fgrep -v -f $bad_files -f $GOOD_SOURCES \
# 	| egrep '[Sch]/[0-9]+-[0-9a-f]{40}$' \
# 	| xargs git grep --no-index --name-only -w -f $bad_lines \
# 	| sort -u > $affected_sources



# function rm_files() {
# 	local args=()
# 	for f; do
# 		args+=(-o -path "./$f")
# 	done
# 	find . -depth -type d -\( -false "${args[@]}" -\) -exec rm -rf '{}' \;
# }
# # rm_files \
# # 	\*.bin \
# # 	\*.pyc \
# # 	\*.d \
# # 	\*.o \
# # 	test.txt \
# # 	test_svn_ticket.txt \
# # 	GNUmakefile_test \
# # 	GNUmakefile_test_full \
# # 	third-party/lib/zlib-1.2.8/README \
# # 	third-party/lib/zlib-1.2.8/\*.i \


find . -depth -type f | pcregrep '(?x) ^\./(
	  .*\.([od]|bin|py[co]|orig|edited)
	| \.gitattributes
	| \.settings/org\.eclipse\.mylyn\. .*
	| \.config2
	| (scripts/)?\.config2.in
	| docs?/ ( socket\.dvi | embox\.(png|ps) )
	| core
	| test(_svn_ticket)?\.txt
	| GNUmakefile_test(_full)?
	| scripts/md5_checksummer/imagetext.bin
	| src/tests/elf/embox
	| src/kernel/timer/heap_timer\.c
	| .* /acpi(ca)?/ (?!.*embox|\b(init\.c|Mybuild|Makefile|acenv\.h\.patch)\b).*
	| (third-party/)?lwip/ .*
	| third-party/(em)?linux.*
	| third-party/lib/zlib-1\.2\.8/ (
		  CMakeLists\.txt
		| ChangeLog | FAQ | INDEX | README
		| examples/(README\.examples|zlib_how\.html)
		| make_vms\.com
		| treebuild\.xml
		| zconf\.h\.(cmake)?in
		| zlib\.( 3(\.pdf)? | map | pc(\.(cmake)?in)? )
		| zlib2ansi
		| .*\.([ais]|rule\.mk) )
	| third-party/dropbear-2012\.55/ (?!embox).*
	| .*/zrv (?!/cmds/texteditor/).*
	| .* \b(ovk|icebrick)\b .*
	| templates/tmp/.*
	| src/arch/(boot\.S|makefile)
	| scripts/(linker/)?link_ovkrom\.S
	| src/cmds/[Cc]rash_test\.(c|my)
	| platform/net/cmd/.*
	| src/lib/elf/backup/.*
) / \d+-[0-9a-f]{40} $ ' | xargs rm -f

function on_bogus_ifconfig() {
	local n=$(basename $f | cut -d- -f1)
	if (( n < 1262104596 )); then
		"$@"
	else
		cat
	fi
}

for f in $(find src/{tests,user}/ifconfig -type f); do
	on_bogus_ifconfig rm -rf $f < /dev/null
done

{
	cat $TOOLS_DIR/bad-sources.txt | xargs rm -rf
	cat $TOOLS_DIR/bad-dirs.txt | xargs rm -rf
	find . -depth -type d -empty -exec rm -rf '{}' \;
} | (egrep '^removed directory' || true)

cat $affected_sources > $TMP_FILE
cat $TMP_FILE | xargs ls 2>/dev/null > $affected_sources



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


function when() {
	local n=$(basename $f | cut -d- -f1)
	local w=$1; shift
	if (( n == w )); then
		"$@"
	else
		cat
	fi
}

function replace_version() {
	cat > /dev/null
	cat $(dirname $f)/$1-*
}
fix when 1228220419 replace_version 1228236732 \
	-- \
	src/common/makefile \
	src/conio/makefile \
	src/drivers/makefile \
	src/tests/makefile \
	src/kernel/traps.S \
	src/kernel/makefile \
	src/makefile

fix when 1228220419 pcregrep -wv 'OBJ_DIR_SIM' \
	-- \
	src/common/makefile \
	src/conio/makefile \
	src/drivers/makefile \
	src/tests/makefile \
	src/kernel/makefile

fix when 1228220419 perl_sed 's/(?<=^all:) simulation(?= release)//mg' \
	-- src/makefile
fix when 1228220419 pcregrep -Mv '^simulation:.*?(\n\t.*)+\n{0,2}' \
	-- src/makefile

# XXX not tested
fix perl_sed 's/(?<=^SUBDIRS = arch)itectures//mg' \
	-- src/makefile

fix -v perl_sed 's/(?<=#include "traps\.inc).S//' \
	-- src/kernel/traps.S

fix -v pcregrep -Mv '(^\s*!.*$\n)*^\s*sta %g0, \[%g0\]0x19' \
	-- \
	src/arch/sparc/boot.S \
	src/arch1/boot.S \
	src/architectures/boot.S \
	src/architectures/sparc/boot.S \
	src/kernel/boot.S

fix $TOOLS_DIR/cleanup-code.sh \
	--directives 'NOT_INIT_MEM' -- \
	src/arch/sparc-obsolete/boot.S \
	src/arch/sparc/boot.S \
	src/arch1/boot.S \
	src/architectures/boot.S \
	src/architectures/sparc/boot.S \
	src/kernel/boot.S


fix -v perl_sed 's/(?<=\n)\n+(?=\n\n)//mg' \
	-- \
	src/arch/sparc-obsolete/boot.S \
	src/arch/sparc/boot.S \
	src/arch1/boot.S \
	src/architectures/boot.S \
	src/architectures/sparc/boot.S \
	src/kernel/boot.S

fix -v perl_sed 's/(?<=#define DATA_SIZE   )0x100000/0x20000/mg' \
	-- src/kernel/memory_map.h
fix -v perl_sed 's/(?<=#define DATA_SIZE   0x20000)0//mg' \
	-- \
	include/asm-sparc/memory_map.h \
	src/arch/sparc-obsolete/include/asm/memory_map.h \
	src/arch/sparc/include/asm/memory_map.h \
	src/arch/sparc/memory_map.h \
	src/architectures/sparc/memory_map.h \
	src/kernel/memory_map.h

function mk_script() {
	cat > $1
	chmod a+x $1
}

mk_script 1228220419-1229966215.sh <<EOF
if [[ ! -f src/kernel/traps.inc ]]; then
	mv -T src/kernel/traps.inc.S src/kernel/traps.inc
elif [[ -f src/kernel/traps.inc.S ]]; then
	rm -f src/kernel/traps.inc.S
fi
EOF

mk_script 0-1237790674.sh <<EOF
if [[ -d src/architectures ]]; then
	mv -T src/architectures src/arch
fi
EOF

mk_script 0-1234443990.sh <<EOF
sed -i 's/Werror/Wall/g' makefile
EOF

mk_script 0-1260806555.sh <<EOF
find . -type f -name 'OVK[_-]configure*' | while read -r file; do
	mv -T "$$file" "$${file/OVK[_-]/}"
done
EOF

# fix -v sed -e 's/[ \t]*$//' -e 's/\r//g' -e '/.$/a\' \
# 	-- .

fix pcregrep -v 'src/kernel/Copy.+of.+Time.my' \
	-- .gitignore

function gitignore_fix() {
	if pcregrep -q '^.+?\*\.[od]' < $f; then
		pcregrep -v '^.+?\*\.[od]' || true
		echo; echo '*.o'; echo '*.d'; echo
	else
		cat
	fi | \
	if pcregrep -q '^.+?\*\.pyc' < $f; then
		pcregrep -v '^.+?\*\.pyc' || true
		echo; echo '*.pyc'; echo
	else
		cat
	fi | \
	perl_sed 's/(?<=\n)\n+(?=\n)//mg' | \
	pcregrep -v '/\b\w+\.inc\b' || true
}
fix -v gitignore_fix  \
	-- .gitignore

fix -v pcregrep -v '\[!!-~\]' \
	-- .gitignore

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

fix $TOOLS_DIR/cleanup-json.py \
	--words 'flash tcpdump' \
	-- \
	.config \
	.config.default \
	.config.in \
	config \
	config.default \
	scripts/.config.in

fix pcregrep -v 'MONITOR_(DRIVER|USER|IF)_FLASH|MONITOR_USER_TCPDUMP' \
	-- \
	scripts/autoconf \
	scripts/autoconf.default \
	scripts/autoconf.h \
	scripts/autoconf.h.in \
	scripts/autoconf.in \
	scripts/autoconf_mb \
	src/drivers/makefile \
	src/user/makefile

fix pcregrep -v '(?x)
		  flashinfo
		| lspart
		| romfs
		| tcpdump
	' -- \
	templates/microblaze \
	templates/sparc

fix pcregrep -v 'romfs' -- \
	src/fs/rootfs.c \
	src/fs/rootfs_desc.inc

fix pcregrep -vM '/\*
#include .mbfs_fileop\.h.
#include .mbfs_fsop\.h.
#include .mm_fileop.
\*/' -- \
	src/fs/rootfs_new.c

fix perl_sed 's/(?<=^extern FSOP) mbfs_fsop,(?= memseg_fsop;)//mg' \
	-- src/fs/rootfs_new.c
fix pcregrep -v 'mbfs_fsop' \
	-- src/fs/rootfs_new.c

fix -v perl_sed '
		s/
			(?: ((?<![=\s]))? [^\S\n]* (\\)? \n )?
			(?: ^\s* \#)? ([^\S\n])* (?: (\S)*? (?<![,()\$\\]) (?(4)(?<!=)) )? \b (
			  flash |flashinfo | romfs | tcpdump
			) \b (?!.*=) (?: (?![,()\$\\]) \S* )?
			(?(1) (?(2)| [^\S\n]* \\$ ))?
			(?(3)| [^\S\n]*+ (?! \\ \n))?
		//xmg;

		s/.*\+=\s*?\n//mg;
		s/(.+)\s*?:=\s*?\$\(filter-out,\$\(\1\)\)\s*?\n//mg;
	' -- \
	src/drivers/makefile \
	src/user/makefile \
	src/user/Makefile \
	src/user/subdirs \
	src/tests/subdirs \
	src/tests/makefile \
	src/fs/Makefile \
	src/fs/makefile \
	src/fs/fs.mmod



fix -v pcregrep -vM '
# XXX
\$\(IMAGE\):(?s:.){0,5}\.\./embox_ovk_piggy/build/base/bin/embox\.piggy' -- \
	mk/image.mk


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
	templates/microblaze/compiler_tests/options-shell.conf \
	templates/microblaze/microblaze_release/options-shell.conf \
	templates/microblaze/release/options-shell.conf \
	templates/microblaze/embox-usr.conf \
	templates/microblaze/options-shell.conf \
	templates/microblaze/ugly.conf \
	templates/microblaze/usr.conf \
	templates/sparc/ugly.conf

fix perl_sed '
		s/\b(MONITOR_DRIVERS?_TERCOM_AMBA_PNP)\b(\S*[^\S\n]{2,})(?!$)/\1\2       /g;
		s/\b(MONITOR_DRIVERS?)_TERCOM(_AMBA_PNP)\b/\1\2/g;
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

fix -v $TOOLS_DIR/cleanup-json.py \
	--words-file $blacklist \
	--words 'align version' \
	-- \
	.config \
	.config.default \
	.config.in \
	config \
	config.default \
	scripts/.config.in

fix -v perl_sed 's/,\s+"Drivers": \[\]//mg' \
	-- \
	.config.default \
	.config.in \
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
			^( \b(?:ROOT_DIR)\b \s*?(\s)? ) (?: \s (?!:))? :?=
			( .*? \b(ovk|pwd)\b | \s*? \$\(CURDIR\) ) .*? $
			(\n ^\# .*? $)*
		/\1:=\2\$(CURDIR)/xm;
		s/^(ROOT_DIR):=(\$\(CURDIR\))$/\1 := \2/m;
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
			  \b( aurctrl
				| brdstats
				| emac
				| ethsend
				| ethlisten
				| ethtest
				| ioboardwr
				| ioboardrd
				| mdio
				| mdiow
				| mdior
				| pwrctrl
				| sgctrl
				| synchro
				| test_io_ctrl
				| test_data_manager
				| ifconfig
				| test_synchronization
				| version
				| tcpdump )\b
			.*?\]
		//xmg;
	' -- \
	OVK-configure.py

fix pcregrep -Mv '(^\s*)if.*?\b(ovk|version_module)\b(.|\n)*?(\n\1\s+.*)+' \
	-- scripts/OVK-configure.py
fix pcregrep -wv 'ovk' \
	-- OVK-configure.py

fix -v perl_sed 's/!= "version"/!= "wmem"/g' \
	-- \
	OVK-configure.py \
	scripts/OVK-configure.py

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

fix egrep -iv \
	-f $bad_symbols_found \
	-e '(io|cpu).?board|data.?manager' \
	-- \
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
	src/kernel/traps.inc.S \
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
	src/arch/sparc/boot.S \
	src/arch1/boot.S \
	src/architectures/boot.S \
	src/architectures/sparc/boot.S \
	src/kernel/boot.S \
	src/user/shell/start_script.inc \
	src/cmds/shell/start_script.inc \
	src/conio/start_script.inc

fix -v pcregrep -v 'chanwatch' \
	-- src/user/shell/start_script.inc

fix -v pcregrep -v '_SYNCHRONIZE' \
	-- \
	src/include/embox/runlevel.h \
	src/include/kernel/init.h

fix -v $TOOLS_DIR/cleanup-code.sh \
	--functions 'dispatch_full_align_trap' \
	-- src/kernel/irq.c

fix -v $TOOLS_DIR/cleanup-code.sh \
	--functions 'timers_align' \
	-- \
	src/drivers/amba_pnp/gaisler/timer/timers.c \
	src/drivers/gaisler/timer/timers.c \
	src/drivers/timers.c

fix -v $TOOLS_DIR/cleanup-code.sh \
	--functions 'irq_ctrl_align' \
	-- \
	src/drivers/amba_pnp/gaisler/irq_ctrl/irq_ctrl.c \
	src/drivers/gaisler/irq_ctrl/irq_ctrl.c \
	src/drivers/irq_ctrl.c

fix -v pcregrep -v 'full_align_irq_mask' \
	-- src/drivers/amba_pnp/gaisler/irq_ctrl/irq_ctrl.c

fix -v perl_sed 's/
		(^.*?brai\sfull_align_entry.*?$)\n
		(^.*?\/\/brai\s_interrupt_handler$)
		|(?2)\n(?1)
	/\tbrai _interrupt_handler/xmg' \
	-- src/arch/microblaze/kernel/entry.S

fix -v perl_sed 's/\s*\b__align_data\b//mg' \
	-- \
	src/arch/sparc/apb_irq_ctrl.c \
	src/arch/sparc/apb_timers.c \
	src/drivers/amba_pnp/gaisler/depricate_irq_ctrl/irq_ctrl.c \
	src/drivers/amba_pnp/gaisler/depricate_timer/timers.c \
	src/drivers/amba_pnp/gaisler/irq_ctrl/irq_ctrl.c \
	src/drivers/amba_pnp/gaisler/timer/timers.c \
	src/drivers/amba_pnp/gaisler/uart/uart.c

fix $TOOLS_DIR/cleanup-code.sh \
	--directives '0' \
	-- src/user/ifconfig/ifconfig.c

# fix perl_sed 's/ethtest_help.inc/ifconfig_help.inc/' \
# 	-- src/tests/ifconfig/ifconfig_help.inc

fix -v on_bogus_ifconfig $TOOLS_DIR/cleanup-json.py \
	--words 'ifconfig' \
	-- \
	.config \
	.config.default \
	.config.in \
	config \
	config.default \
	scripts/.config.in


fix -v on_bogus_ifconfig pcregrep -v 'ifconfig' \
	-- \
	OVK-configure.py \
	src/user/shell/start_script.inc \
	src/conio/shell.h \
	src/conio/shell.inc \
	src/conio/tests.inc \
	src/conio/users.inc \
	templates

fix -v on_bogus_ifconfig perl_sed '
		s/
			(?: ((?<![=\s]))? [^\S\n]* (\\)? \n )?
			(?: ^\s* \#)? ([^\S\n])* (?: (\S)*? (?<![,()\$\\]) (?(4)(?<!=)) )? \b (
				ifconfig
			) \b (?: (?![,()\$\\]) \S* )?
			(?(1) (?(2)| [^\S\n]* \\$ ))?
			(?(3)| [^\S\n]*+ (?! \\ \n))?
		//xmg;

		s/.*\+=\s*?\n//mg;
		s/(.+)\s*?:=\s*?\$\(filter-out,\$\(\1\)\)\s*?\n//mg;
	' -- \
	src/user/makefile \
	src/user/Makefile \
	src/user/subdirs  \
	src/tests/makefile \
	src/tests/subdirs


fix perl_sed 's/,(?=\s*\Z)//m' \
	-- \
	src/user/lspnp/pnp_vendors_table.inc \
	src/conio/shell.inc \
	src/drivers/amba_pnp/pnp_devices_table.inc \
	src/drivers/amba_pnp/pnp_vendors_table.inc \
	src/drivers/pnp_devices_table.inc \
	src/drivers/pnp_vendors_table.inc \
	src/tests/tests_table.inc


fix -v pcregrep -v '"eth\.h"' \
	-- \
	src/conio/shell.c \
	src/conio/shell.h \
	src/tests/help/help.c


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

fix perl_sed 's/(?<!\/\/ )eth_dev_(open|close)/\/\/ eth_dev_\1/g' \
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


# fix -v sed '/.$/a\' -- .
