# Bundled English swipe vocabulary

`Sources/KeyboardCore/Resources/swipe-english.txt` is a generated, offline English
word list from Kevin Atkinson's English Speller Database (ESDB), previously SCOWL.
It contains 38,604 lowercase word forms. The dictionary is data, separate from
TabForge's MIT-licensed implementation; its applicable permission notice is below.

No user typing, gesture traces, supplementary lexicon entries, or other user data
were used to produce this list. The keyboard does not download or update it.

## Provenance and reproduction

- Upstream: <https://github.com/en-wl/wordlist>
- Revision: `1e5b7d3a72f47a71da5d28686c1dd4b397178485` (`v2` branch).
- Source archive: <https://codeload.github.com/en-wl/wordlist/tar.gz/1e5b7d3a72f47a71da5d28686c1dd4b397178485>
- Source archive SHA-256: `aaecc7a54af576057e30b22a19b78bad011f2181f7e368ff3b736fbecbdfd4d0`.
- Generated list: 343,537 bytes, SHA-256 `90dad9e54d4475647ac2782ea2abe090a208b3ab3b5c324bd606fca30d692f42` (including its copyright/source comments).
- Importer: [Scripts/import-swipe-lexicon.py](../Scripts/import-swipe-lexicon.py).

With Python 3.7 or later, SQLite 3.33 or later, and `curl` available:

```sh
python3 Scripts/import-swipe-lexicon.py
python3 Scripts/import-swipe-lexicon.py --check
```

The importer downloads and verifies the pinned source archive, builds its
temporary database with the upstream generator, and queries its `scowl_v0` view.
It removes the temporary source and database afterward. Use `--archive PATH` to
reproduce from a previously downloaded tarball without a network request. These
are contributor commands, not app behavior. Generation takes roughly a minute
on a development Mac; the generated file ships with the app.

The extraction selects ESDB size 35, its recommended small dictionary. ESDB sizes
are broad vocabulary/commonness categories, not measured word frequencies. The
whole eligible tier is retained; it is not truncated alphabetically. The SQL
allows general or American spelling, general or US regions, and variant levels
through 1. It excludes special categories and word parts, abbreviations, and
entries classified as names, places, people, surnames, demonyms, trademarks, or
uppercase/abbreviation candidates. Number and ordinal words remain eligible.

Any spelling marked `offensive-*` or `vulgar-*` in an upstream group is excluded
even if another group gives the same spelling an unmarked meaning. That metadata
is incomplete; this filter is not a guarantee that every sensitive word is
removed. Only originally lowercase ASCII forms of 2–24 letters are retained.
Capitalized words are not converted to lowercase, and accents are not removed.
Inflected forms remain included, including `testing` and `programming`.

Names and acronyms outside this list, arbitrary identifiers, apostrophized words,
and non-English text may need tap typing. A broader dictionary improves coverage;
it does not by itself establish system-keyboard recognition accuracy.

## Applicable upstream permission notice

The upstream [Copyright file](https://github.com/en-wl/wordlist/blob/1e5b7d3a72f47a71da5d28686c1dd4b397178485/Copyright)
states that a generated non-Australian word list of size 80 or lower needs only
the notice before its first `===` separator. This list uses size 35, does not use
Australian spelling/region codes, and is a generated word list rather than a
redistribution of the database. The applicable notice is reproduced here:

```text
Copyright 2000-2026 by Kevin Atkinson
Permission to use, copy, modify, distribute, and sell any part of the English
Speller Database (ESDB, previously known as SCOWLv2), or word lists
created from it, is hereby granted without fee, provided that the above
copyright notice appears in all copies and that both the above copyright
notice and this notice appear in supporting documentation.  Kevin Atkinson
makes no representations about the suitability of this database for any
purpose.  It is provided "as is" without express or implied warranty.
ESDB is derived from many sources, most of which are in the Public Domain.
Data from the Corpus of Contemporary American English (COCA) was also used.

All data from COCA comes from 3-gram data that is not freely available;
however, the usage is within the rights given by the NDA that was signed when
purchasing the data.  More information on COCA is available at
https://www.english-corpora.org/coca/.
The primary source of words for ESDB comes from 12dicts and ENABLE2K.  Both
are in the Public Domain, but Alan Beale <biljir@pobox.com> deserves special
credit as he is the author of 12dicts and a major contributor to ENABLE2K.  In
addition, he gave me an incredible amount of feedback and created a number of
special lists in order to help improve the overall quality of ESDB.
```

Preserve this notice with redistributed or modified copies of the generated
word list. No Ortholinear language data, `wordfreq` data, FUTO weights, or FUTO
inference code is bundled by this import.
