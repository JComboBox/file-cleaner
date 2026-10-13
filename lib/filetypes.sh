#!/usr/bin/env bash
# File type detection. A "type" names both a cleaner (cleaners/<type>.sh)
# and a validator (validators/<type>.sh).

[[ -n "${_FC_FILETYPES_LOADED:-}" ]] && return 0
_FC_FILETYPES_LOADED=1

# detect_type FILE — print the type for FILE, or nothing if unsupported.
detect_type() {
  local file="$1" base ext first
  base="$(basename "$file")"
  ext="${base##*.}"
  [[ "$ext" == "$base" ]] && ext=""

  case "${ext,,}" in
    sh|bash)                          echo shell; return ;;
    py)                               echo python; return ;;
    js|mjs|cjs)                       echo javascript; return ;;
    ts|tsx|jsx)                       echo typescript; return ;;
    java|c|h|cc|cpp|hpp|cs|kt|swift|rs|scala) echo c-family; return ;;
    go)                               echo go; return ;;
    json)                             echo json; return ;;
    yml|yaml)                         echo yaml; return ;;
    xml|xsd|pom|csproj)               echo xml; return ;;
    html|htm)                         echo html; return ;;
  esac

  # No useful extension: fall back to the shebang.
  if [[ -z "$ext" && -f "$file" ]]; then
    IFS= read -r first < "$file" || true
    case "$first" in
      '#!'*bash*|'#!'*/sh|'#!'*' sh') echo shell; return ;;
      '#!'*python*)                   echo python; return ;;
      '#!'*node*)                     echo javascript; return ;;
    esac
  fi
}

# type_enabled TYPE — true if TYPE is in $FC_TYPES (or FC_TYPES is empty).
type_enabled() {
  [[ -z "${FC_TYPES:-}" ]] && return 0
  [[ " ${FC_TYPES//,/ } " == *" $1 "* ]]
}
