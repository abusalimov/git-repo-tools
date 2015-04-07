#!/bin/bash

dir="$(dirname $0)"
read -r TIMESTAMP _ <<< "${GIT_AUTHOR_DATE#@}"


if (( TIMESTAMP >= 1254845614 )); then
	exit
fi

mkdir -p src/arch

if (( TIMESTAMP == 1235568003 )); then
# 	cat $dir/restored-old.makefile > src/arch/makefile
# fi

# if (( TIMESTAMP == 1237729137 )); then
	git checkout-index -q -f -- src/arch/makefile
fi

if (( TIMESTAMP == 1244707739 )); then
	cat $dir/restored.makefile > src/arch/makefile
fi

git checkout-index -q -f -- src/arch/Makefile

[[ -f src/arch/Makefile ]] || git update-index --add --remove -- src/arch/makefile
