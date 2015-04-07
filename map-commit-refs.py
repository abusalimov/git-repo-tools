#!/usr/bin/env python2

from __future__ import print_function


import re
import sys
from glob import glob

def fixup_refs(s):
    def fix_ref(match):
        commit = match.group()
        glob_pat = commit.ljust(40, '?')
        try:
            filename, = glob('../map/{}'.format(glob_pat))
        except ValueError:
            raise ValueError('Error mapping commit {}'.format(commit))
        with open(filename) as f:
            mapped, = f
        return mapped[:7]

    return re.sub(r'\b[0-9a-f]{40}\b', fix_ref, s)


def main():
    sys.stdout.write(fixup_refs(sys.stdin.read()))


if __name__ == "__main__":
    main()
