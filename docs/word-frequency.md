# Bundled English word frequencies

`Sources/KeyboardCore/Resources/english-frequency.txt` gives a frequency to 35,129 of the
38,604 words in the [bundled swipe vocabulary](swipe-lexicon.md). Autocorrect, swipe,
and English suggestions use it to prefer common words when several fit the taps or
path about equally well. It adds no new words: it is the intersection of the ESDB list
with SymSpell's English frequency dictionary.

No user typing, gesture traces, or other user data were used to produce it. The
keyboard does not download or update it.

## Format

Each line is `word<TAB>value`, where value is the word's Zipf frequency × 10, rounded.
Zipf is the base-10 logarithm of occurrences per billion words, so `the` is 76 and a
word seen once per million words is 30. Lines starting with `#` are comments. Covered
words range from 1.4 to 7.6 on the Zipf scale (median 3.2). The 3,475 ESDB words that
SymSpell does not list are treated as Zipf 2.0 at run time. Programming terms bundled
in code are never ranked below Zipf 4.0.

## Provenance and reproduction

- Upstream list: `frequency_dictionary_en_82_765.txt` from [SymSpell](https://github.com/wolfgarbe/SymSpell)
  by Wolf Garbe, as packaged in [symspellpy](https://github.com/mammothb/symspellpy) 6.9.0.
- Wheel: `symspellpy-6.9.0-py3-none-any.whl` from PyPI, SHA-256
  `b6dba96275fdbedc240491854160bbe596dda930f2d58567ad55faf82a4e4b43`.
- Dictionary member SHA-256: `68e9dc81c7e73bd7310b57e516ecaea0d8b6387ff71344a57c04174650a407a7`.
- Generated file: 416,082 bytes, SHA-256
  `76f7d50f225f257fc18412509e51a6f14ec6a23cdc8556eebcf1fde8acc6bf07`.
- Importer: [Scripts/import-word-frequencies.py](../Scripts/import-word-frequencies.py).

```sh
python3 Scripts/import-word-frequencies.py
python3 Scripts/import-word-frequencies.py --check
```

The importer downloads and verifies the pinned wheel (or uses `--wheel PATH`), reads
only the dictionary file from it, and runs no code from the package. These are
contributor commands, not app behavior.

SymSpell's README describes the dictionary as the intersection of Google Books Ngram
data, which provides the counts, and SCOWL, which limits it to genuine English words.
Because TabForge keeps only words that are also in its ESDB list, the offensive and
vulgar filtering described in [the vocabulary provenance](swipe-lexicon.md) still applies.

## Licenses and attribution

The symspellpy package, including this dictionary file, is distributed under the MIT
license below. The underlying counts come from the
[Google Books Ngram](https://books.google.com/ngrams) data, which SymSpell credits under
[Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/). TabForge
reduced the counts to rounded Zipf values for its own word list. Google does not
sponsor or endorse TabForge. The companion app credits SymSpell, symspellpy, and Google
Books Ngram under Settings → Built with.

```text
MIT License

Copyright (c) 2025 mmb L (Python port https://github.com/mammothb/symspellpy)
Copyright (c) 2021 Wolf Garbe (Original C# implementation https://github.com/wolfgarbe/SymSpell)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
