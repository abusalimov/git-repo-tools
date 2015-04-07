#!/usr/bin/env python


def main():
    import sys

    if len(sys.argv) == 2:
        commits_filename = sys.argv[1]
    else:
        commits_filename = 'git-msg-fixed'

    commits = []

    with open(commits_filename) as f:
        for line in f:
            if line.startswith('======== @'):
                ts = line.split()[1][1:]
                if not ts:
                    raise ValueError(line)
                lines = []
                commits.append((ts, lines))
            else:
                lines.append(line)

    for ts, lines in commits:
        while lines and not lines[-1].rstrip('\n').strip():
            lines.pop()

        if not lines:
            lines.append('[No commit log message]')

        lines[-1] = lines[-1].rstrip('\n')

        with open('out/'+ts, 'w+') as f:
            f.writelines(lines)

if __name__ == '__main__':
    main()
