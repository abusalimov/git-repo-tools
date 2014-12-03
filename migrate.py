#!/usr/bin/env python
"""
Helper tool for migrating Embox SVN@GC repo history to Git@GH.
  -- Eldar
"""

from collections import Counter
from collections import namedtuple
import re
import string

sentence_re = re.compile(
    r'''\s*
        (?P<sentence>
            (?: (?: \[+ .*? \]+
                  | \(+ .*? \)+
                  | \{+ .*? \}+ ) \s*
              | .)+?

            (?<! \s )
            (?: (?<! e\.g | i\.e | mrs ) (?<! mr ) (?<! r\.i\.p ) \.
              | [.?!]{2,3} | [;?!]{1,3}
              | (?= \s* $ ) ) ) [;.?!]*

        (?: (?: (?<= ; ) | (?<= [.?!] ) \s) (?P<tail> .*? ) )?
        \s* $
    ''', re.X | re.I)

def extract_sentences(line, semicolon=False):
    sentences = []

    line = line.strip()
    while line:
        match = sentence_re.match(line)
        if not match:
            break

        sentence = match.group('sentence')

        if not semicolon and sentences and sentences[-1].endswith(';'):
            if line.startswith(' '):
                sentences[-1] += ' '
            sentences[-1] += sentence
        else:
            sentences.append(sentence)

        line = match.group('tail')

    return sentences

list_item_re = re.compile(r'''\s{,4}[-*\d]{1,3}\s?[.)]?\s*''')

def join_lines(lines):
    """Resulting string must be used for analyzing only"""
    new_list = []

    for line in lines:
        match = list_item_re.match(line)
        if match:  # remove bullet
            line = line[match.end():] or ' '  # but don't let empty lines

        if new_list and not new_list[-1][-1] in ';.?!':
            new_list[-1] += (';' if line else '.')

        if line:
            new_list.append(line)

    return ' '.join(new_list)


issue_keyword_re = re.compile(r'\bissues?', re.I)
issue_number_re = re.compile(
    r'''\s* .{,3}? \s*
        (?: (?<! [a-zA-Z0-9] ) | (?<= issue ) | (?<= issues ) )
        (?P<number> \d+ )\b
    ''', re.X | re.I)

def extract_issues(line):
    issues = []

    pos = 0
    while True:
        match = issue_keyword_re.search(line, pos)
        if not match:
            break

        while True:
            pos = match.end()
            match = issue_number_re.match(line, pos)
            if not match:
                break

            issue = int(match.group('number'))
            if issue not in issues:
                issues.append(issue)

    return issues


label_re = re.compile(
    r'''\s*
        (?P<label>
            \[+ .+? \]+
          | \(+ .+? \)+
          | .+? : )
    ''', re.X | re.I)

label_keyword_re = re.compile(
    r'''((an?|the)\s+)?

        ((little|major|minor|some|small|(in)?significant|various)\s+)?

        \b(?P<keyword>
            (fix) (?=es|ed|ing)?
          | (work) (?=(ing)? (?=\s+(on|at)\b))

          | (add|clean(up)?|implement|refactor|revert
              |rework|workaround) (?=s|ed|ing)?

          | (?P<noe>chang|clos|improv|introduc|issu|merg|(re)?mov
              |renam|rewrit|updat|us) (?=e|es|ed|ing)?   )

    ''', re.X | re.I)

def extract_labels(line, is_branch=False):
    labels = []
    tags = []
    keywords = []

    pos = 0
    while True:
        label_match = label_re.match(line, pos)
        if not label_match:
            break

        label = label_match.group('label').lower()

        keyword_match = label_keyword_re.match(label)
        if keyword_match:
            keyword = keyword_match.group('keyword')
            if keyword_match.group('noe'):
                keyword += 'e'
            if keyword not in keywords:
                keywords.append(keyword)

        elif label.endswith(':'):
            if len(label.split()) > 3:
                break
            label = label.strip(':')
            if label not in labels:
                labels.append(label)

        else:
            frags = list(filter(None, label.strip('[]()').split(':')))
            if len(frags) == 1 and not is_branch:
                tag = frags[0]
                if tag not in tags:
                    tags.append(tag)

            else:
                for label in frags:
                    if label not in labels:
                        labels.append(label)

        pos = label_match.end()

    return labels, tags, keywords#, line[pos:]


Commit = namedtuple('Commit', 'git_id, svn_id, svn_branch, msg_lines')

def read_commits(filename):
    commits = []

    with open(filename) as f:
        for line in f:
            if line.startswith('================'):
                _, git_id, svn_id, svn_branch = line.split()
                if svn_branch == 'trunk/embox':
                    svn_branch = ''
                commit = Commit(git_id, svn_id, svn_branch, [])
                commits.append(commit)
            else:
                commit.msg_lines.append(line.rstrip('\n').strip())

    for commit in commits:
        lines = commit.msg_lines
        while len(lines) > 1 and not lines[-1]:
            lines.pop()
        while len(lines) > 1 and not lines[0]:
            lines.pop(0)
        # if not lines:
        #     lines.append('')  # XXX

    return commits


def print_suspicious_abbrevs(commits):
    punkt2space = string.maketrans(',./!&?;:#@"^\'',
                                   '             ')
    abbrev_like = set()
    for commit in commits:
        sentences = extract_sentences('. '.join(commit.msg_lines))
        for sentence in sentences:
            last_word = sentence.rpartition(' ')[-1]
            if (last_word.endswith('.') and
                len(last_word.translate(punkt2space).split()) > 1):
                abbrev_like.add(last_word)

    for word in sorted(abbrev_like):
        print(word)


def print_labels(commits):
    tup = labels, tags, keywords = Counter(), Counter(), Counter()

    for commit in commits:
        text = join_lines(commit.msg_lines)
        for sent in extract_sentences(text, semicolon=True):
            for cnt, lst in zip(tup, extract_labels(sent,
                    is_branch=bool(commit.svn_branch))):
                cnt.update(lst)


    for cnt in tup:
        print len(cnt)
        for word, nr in cnt.most_common():
            print nr, '\t', word
        break # print


def print_multiline_commits(commits):
    i = 0
    for commit in commits:
        if commit.msg_lines:
            print commit.msg_lines[0][:78]
        continue

        if (len(commit.msg_lines) == 1 and
            len(commit.msg_lines[0]) < 50):
            print '>>>', commit.msg_lines[0]

        if not (len(commit.msg_lines) > 1 and
                len(commit.msg_lines[1]) > 1):
            if True or not (commit.msg_lines[1][0].isupper() and
                    commit.msg_lines[1][1].islower()):
                sents = extract_sentences(commit.msg_lines[0], semicolon=True)
                if sents and len(sents[0]) > 50:
                    print '>>>', commit.msg_lines[0]
            continue
            i += 1
            print i, '===========', commit.svn_id, commit.svn_branch
            for line in commit.msg_lines:
                print '>>>', line
            print


def print_test_sentences():
    for s in [
                ['dsf'],
                ['dsf.'],
                ['sd; f i.e. dfg '],
                ['sd;   f .. dfg '],
                ['[foo] sdf: fdfg; sdf', '', 'also: xxx', 'and: foo bar baz'],
            ]:
        print extract_sentences(join_lines(s), semicolon=True)


def main():
    import sys

    if len(sys.argv) == 2:
        commits_filename = sys.argv[1]
    else:
        commits_filename = 'embox-commits.txt'

    commits = read_commits(commits_filename)

    # return print_multiline_commits(commits)
    return print_labels(commits)
    return print_test_sentences()



    for commit in commits:
        line = ' '.join(commit.msg_lines)
        # issues = extract_issues(commit.svn_branch + ' ' + line)
        # if len(issues) > 1:
        #     print commit.svn_id, commit.svn_branch, issues
        #     print line
        #     print

        sentences = extract_sentences(line)
        # if not sentences:
        #     continue
        # first = sentences[0]
        # if 'issue' in line.lower():
        #     print commit.svn_id, commit.svn_branch, line
        # print(head)
        # print("\t\t" + tail)
        # if tail == 'XXX' and line:
        #     print(line, commit.svn_id)

if __name__ == '__main__':
    main()
