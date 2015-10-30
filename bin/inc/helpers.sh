#!/usr/bin/env bash
# Color escape codes (for nicer output)
source "$ENVIRONMENT_ROOT/bin/inc/bash-colors.sh"

####################################
# Wrapper for testing file existence
# Arguments:
#   flags - standard if flags
#   path - path to the file
# Returns:
#   boolean
#####################################
test_file() {
  local flags=$1
  local path=$2
  if [ ${flags} ${path} ]; then
    return 1
  fi
  return 0
}

#####################################
# Check an array for a matching item
# Arguments:
#   haystack - array to be checked
#   needle - value to find
# Returns:
#   boolean
#####################################
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

#####################################
# Formats messages in a nice manner
# Arguments:
#   type - The context of the message
#     > options: HINT, WARN, ERROR, *
#   message - Text the be displayed
# Returns:
#   none
#####################################
style_message() {
  # Ensure type is uppercase for case matching
  local type=$( echo "$1" | tr -s  '[:lower:]'  '[:upper:]' )
  # Remove formatting from message
  local message="${FORMAT[nf]}$2${FORMAT[nf]}\n"
  # Style message bassed on type
  case $type in
    "HINT")
      printf "[${FORMAT[lightcyan]}HINT${FORMAT[nf]}] $message"
      ;;
    "WARN")
      printf "[${FORMAT[lightyellow]}WARNING${FORMAT[nf]}] $message"
      ;;
    "ERROR")
      printf "[${FORMAT[lightred]}ERROR${FORMAT[nf]}] $message"
      ;;
    *)
      printf "[$type] $message"
      ;;
  esac
}

######################################
# Formats config data in a nice manner
# Arguments:
#   label - Description of the data
#   value - the config data
# Returns:
#   none
######################################
style_config() {
  # Capitialise the label
  local label="$(tr '[:lower:]' '[:upper:]' <<< ${1:0:1})${1:1}"
  # Format value
  local value="$2\n"
  # Style message
  printf "${FORMAT[lightcyan]}$label:${FORMAT[nf]} $value"
}

######################################
# Styles up a line
# Arguments:
#   params - array of all parameters
#   message - the last parameter
# Returns:
#   none
######################################
style_line() {
  local params=("$@")
  local message=${params[-1]}
  local style=""
  unset params[${#params[@]}-1]

  for param in "${params[@]}"; do
    $style="$style$FORMAT[$param]"
  done

  printf "${style}$message${FORMAT[nf]}\n"

}