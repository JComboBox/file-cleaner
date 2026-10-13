# Rules

`rules/<type>.patterns` lists extended regular expressions (POSIX ERE, as
understood by `awk`), one per line. Any line in a file of that type matching
one of them is deleted. Lines starting with `#` and blank lines are ignored.

Patterns are applied before header removal and before validation, so a
pattern that breaks syntax is caught and the file reverted.

Keep patterns anchored (`^...$`) wherever possible — an unanchored pattern
can match far more than intended.
