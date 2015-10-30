#!/usr/bin/env bash
# Color escape codes (for nicer output)
source "$ENVIRONMENT_ROOT/bin/inc/bash-colors.sh"

# Wrapper for testing file existence
test_file() {
  if [ "${1}" "${2}" ]; then
    return 1
  fi
  return 0
}

# Function to check if item is in array
in_array() {
    local haystack=${1}[@]
    local needle=${2}
    for i in ${!haystack}; do
        if [[ ${i} == ${needle} ]]; then
            return 0
        fi
    done
    return 1
}

# Message styler
style_message() {
  local type="${$1^^}"
  local message="[$type]${FORMAT[nf]} $2\n"
  case $type in
    "HINT")
      printf "${FORMAT[lightcyan]}${FORMAT[bold]}[$type]${FORMAT[nf]} $message\n"
      ;;
    "WARNING")
      printf "${FORMAT[lightyellow]}${FORMAT[bold]}[$type]${FORMAT[nf]} $message\n"
      ;;
    "ERROR")
      printf "${FORMAT[lightred]}${FORMAT[bold]}$message"
      ;;
    *)
      printf "$message"
      ;;
  esac
}

# Message styler
style_config() {
  local label="${$1^}"
  local value="$2\n"
  printf "${FORMAT[lightcyan]}$label:${FORMAT[nf]} $value"
}