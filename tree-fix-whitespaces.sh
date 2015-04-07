#!/bin/bash
#
# git filter-branch \
#     --tree-filter "tree-fix-whitespaces.sh" \
# --tag-name-filter cat -- --all
#
# Removes trailing whitespaces, converts CRLF -> LF.
# Ensures a newline at the end of file.
#

# XXX Must filter-out binary files
#   -exec sh -c 'file -b --mime-type "$0" | grep -wq -e text -e xml' \;
find . -type f -exec sed -i -e 's/[ \t]*$//' -e 's/\r//g' -e '/.$/a\' '{}' \;
