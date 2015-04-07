#!/usr/bin/env python2

from __future__ import print_function


import optparse
import re
import sys


REF_RE = r'''(?x)
    ( (?P<issue>
        (?<![?\-])\b[Ii]s[su]{2}e (?=\d*\b) [ \t#-]* )+

    | (?P<commit>
        \b([Rr]ev(ision)?|[Cc]ommit) (?=\d*\b) [ \t#-]*
      # nobody cares about linking to the first 100 commits :(
      | ((\br|(?P<at>@)\b)(?=\d{3,}\b)) )+ )

    (?P<u>(?<=\?))?
    ( (?(u)[&\w\-=%]*?\b(?(issue)id|r)=)
      (?P<value> (?(issue)\d+|(\d+|\b[0-9a-f]{7,40})) )\b (?!=) )?
    (?(u)[&\w\-=%]*)
'''

def fixup_refs(s, add_ref=None):
    def fix_ref(match):
        ref = None

        value = match.group('value')
        if value:
            if match.group('at'):
                value = '@'+value

            if match.group('issue'):
                ref = '#' + str(int(value))
            elif value and commit_map:
                try:
                    ref = commit_map[value]
                except KeyError:
                    output("Warning: no mapping for commit '{}'".format(value))

        if not ref:
            return match.group()

        if add_ref is not None:
            add_ref(ref)

        output("Mapping text ref {:>24} -> {:<6}  :  {:<40}"
               .format(match.group(), value, ref),
               level=2+(ref==match.group()))
        return ref

    return re.sub(REF_RE, fix_ref, s)


def output(string='', level=0, fp=sys.stdout):
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

    if len(args) > 1:
        parser.print_help()
        sys.exit(1)

    if args:
        commits_filename = args[0]
    else:
        commits_filename = 'git-msg'


    commit_map = {}
    for map_filename in reversed(options.commits_map):
        tmp_map = commit_map
        commit_map = dict(tmp_map)
        with open(map_filename, 'r') as f:
            for line in f:
                if not line.strip():
                    continue
                key, value = (s.strip() for s in line.split(None, 1))

                if not tmp_map:
                    commit_map[key] = value
                elif value in tmp_map:
                    commit_map[key] = tmp_map[value]


    commits = []

    with open(commits_filename) as f:
        for line in f:
            if line.startswith('======== @'):
                ts = line.split()[1][1:]
                lines = []
                commits.append((ts, lines))
            else:
                lines.append(fixup_refs(line))

    with open(commits_filename+'-fixed', 'w') as f:
        for ts, lines in commits:
            f.write('======== @{} +0000  ======\n'.format(ts))
            f.writelines(lines)


if __name__ == "__main__":
    main()
