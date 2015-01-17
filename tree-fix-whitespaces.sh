#!/bin/bash
#
# git filter-branch \
#     --tree-filter "tree-fix-whitespaces.sh" \
# --tag-name-filter cat -- --all
#
# Removes trailing whitespaces, converts CRLF -> LF.
# Replaces indentation spaces with tabs.
#

find . -type f -exec sed -ri $'s/[ \t\r]*$//' '{}' \; \
	-name '*.[Sch]' -exec sed -ri $':a;s/^(\t*) {4}/\\1\t/;ta' '{}' \;
