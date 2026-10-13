# Validators

`validators/<type>.sh FILE` checks that a cleaned file is still valid.

Exit codes (the contract `lib/validate.sh` relies on):

| Code | Meaning                                                      |
|------|--------------------------------------------------------------|
| 0    | File is valid                                                |
| 1    | File is invalid — the change will be reverted                |
| 3    | No validator tool available — see `FC_REQUIRE_VALIDATOR`     |

Validators must not modify the file or leave artifacts (e.g. `__pycache__`)
in the working tree.
