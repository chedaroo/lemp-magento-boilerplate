#!/usr/bin/env bash

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