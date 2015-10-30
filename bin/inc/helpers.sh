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
  # Ensure type is uppercase for case matching
  local type=$( echo "$1" | tr -s  '[:lower:]'  '[:upper:]' )
  # Remove formatting from message
  local message="${FORMAT[nf]}$2\n"
  # Style message bassed on type
  case $type in
    "HINT")
      printf "${FORMAT[lightcyan]}${FORMAT[bold]}[HINT] $message"
      ;;
    "WARN")
      printf "${FORMAT[lightyellow]}${FORMAT[bold]}[WARNING] $message"
      ;;
    "ERROR")
      printf "${FORMAT[lightred]}${FORMAT[bold]}[ERROR] $message"
      ;;
    *)
      printf "[$type] $message"
      ;;
  esac
}


# Config styler
style_config() {
  # Capitialise the label
  local label="$(tr '[:lower:]' '[:upper:]' <<< ${1:0:1})${1:1}"
  # Format value
  local value="$2\n"
  # Style message
  printf "${FORMAT[lightcyan]}$label:${FORMAT[nf]} $value"
}