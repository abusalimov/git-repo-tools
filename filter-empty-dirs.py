#!/usr/bin/env python2

from __future__ import print_function

import sys

if __name__ == "__main__":
    prev = None
    for line in sys.stdin:
        line = line.rstrip('\n')

        if prev:
            if not line.startswith(prev):
                print(prev)
            prev = None

        if line and line[-1] == '/':
            prev = line

