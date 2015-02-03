#!/usr/bin/env python3
"""
Filter and format JSON data.
"""

import argparse
import collections
import json
import re
import sys


def read_json(fp=sys.stdin):
    return json.load(fp, object_pairs_hook=collections.OrderedDict)

def write_json(obj, fp=sys.stdout):
    json.dump(obj, fp, indent='\t', separators=(',', ': '))
    fp.write('\n')


class ObjectFilter:
    WORD_SEP_RE = re.compile('[\W_]+')

    def __init__(self, blacklist):
        super(ObjectFilter, self).__init__()
        self.blacklist = blacklist

    def transform(self, obj):
        if not obj:
            return obj

        if isinstance(obj, str):
            return self.transform_str(obj)
        if isinstance(obj, dict):
            return self.transform_dict(obj)
        if isinstance(obj, list):
            return self.transform_list(obj)

        return obj

    def transform_str(self, obj):
        str_lower = obj.lower()
        words = set(self.WORD_SEP_RE.split(str_lower))
        words.add(str_lower)
        if not words.isdisjoint(self.blacklist):
            # print('>>> {obj}'.format(**locals()), file=sys.stderr)
            return
        return obj

    def transform_dict(self, obj):
        struct_like = self.is_struct_like(obj.values())
        ret = collections.OrderedDict()

        for k, v in obj.items():

            k = self.transform_str(k)
            if not k:
                continue

            v = self.transform(v)
            if v is None:
                if struct_like:
                    return
                else:
                    continue

            ret[k] = v

        return ret

    def transform_list(self, obj):
        struct_like = self.is_struct_like(obj)
        ret = list()

        for v in obj:

            v = self.transform(v)
            if v is None:
                if struct_like:
                    return
                else:
                    continue

            ret.append(v)

        return ret

    def is_struct_like(self, it):
        types = map(type, it)
        try:
            a_type = next(types)
        except StopIteration:
            return False
        else:
            return any(t != a_type for t in types)


def main():
    parser = argparse.ArgumentParser(
            description='Reads JSON from stdin, filters it, and writes to stdout')
    parser.add_argument('--words', action='append', default=[])
    parser.add_argument('--words-file', action='append', default=[],
                        type=argparse.FileType())

    args = parser.parse_args()

    blacklist = set()

    for word_list in args.words:
        for word in word_list.split():
            blacklist.add(word.lower())

    for fp in args.words_file:
        for line in fp:
            word = line.rstrip('\n')
            if word:
                blacklist.add(word.lower())

    obj = read_json()
    if blacklist:
        obj = ObjectFilter(blacklist).transform(obj)
    write_json(obj)


if __name__ == '__main__':
    main()
