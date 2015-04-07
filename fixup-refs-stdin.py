#!/usr/bin/env python2

from __future__ import print_function


import optparse
import re
import sys


def fixup_refs(s, add_ref=None):
    def fix_ref(match):
        commit = match.group()
        mapped = commit_map[commit]
        output("Mapping {}  :  {}{}".format(commit, mapped,
               "  !!!" if commit == mapped else ''), level=2)
        return mapped[:7]

    return re.sub(r'(?<!gist\.githubusercontent\.com/anonymous/[0-9a-f]{20}/raw/)\b[0-9a-f]{40}\b', fix_ref, s)


def output(string='', level=0, fp=sys.stderr):
    if options.verbose >= level:
        fp.write(string)
        fp.write('\n')
        fp.flush()


def main():
    global options
    global commit_map

    parser = optparse.OptionParser(
            usage="usage: %prog [options] [file]",
            description="Fix commit references using map(s).")

    include = optparse.OptionGroup(parser, title="Included files")
    include.add_option('--commits-map', action='append', default=[],
            help='Map file(s) for revision references')

    parser.add_option_group(include)

    parser.add_option('-v', '--verbose', action='count', default=0,
            help='Verbosity level (-v to -vvv)')

    options, args = parser.parse_args()

    commit_map = {}
    for map_filename in reversed(options.commits_map):
        tmp_map = commit_map
        commit_map = dict(tmp_map)
        with open(map_filename, 'r') as f:
            for line in f:
                if not line.strip():
                    continue
                key, value = (s.strip() for s in line.split(None, 1))

                # if not tmp_map:
                #     commit_map[key] = value
                # elif value in tmp_map:
                #     commit_map[key] = tmp_map[value]
                commit_map[key] = tmp_map.get(value, value)

    try:
        sys.stdout.write(fixup_refs(sys.stdin.read()))
    except Exception as e:
        output(str(e))
        sys.exit(1)


if __name__ == "__main__":
    main()
