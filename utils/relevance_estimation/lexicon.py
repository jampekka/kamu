#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import re
import codecs

class Lexicon(object):

    def __init__(self, data=None):
        if data is None:
            data = {}
        self.data = data

    def add(self, *words):
        for word in words:
            self.data[word] = self.data.get(word, 0) + 1

    def addString(self, s):
        self.add(*string_to_words(s))

    def dump(self, output=None):
        if output is None:
            output = sys.stdout
        items = list(self.items())
        for (word, freq) in items[::-1]:
            s = '%i %s\n' % (freq, word)
            output.write(s.encode('utf-8'))

    def items(self):
        items = list(self.data.items())
        items.sort(key=lambda w_f: w_f[1])
        return items[::-1]

stripper = re.compile('(?u)[^a-zäöå\-]')


def string_to_words(s):
    s = s.lower()
    s = stripper.sub(' ', s)
    words = s.split()
    return words


def read_lexicon(input):
    data = {}
    input = codecs.getreader('utf-8')(input)
    for row in input:
        row = str(row)
        (freq, word) = row.split()
        freq = int(freq)
        data[word] = int(freq)
    return Lexicon(data)


