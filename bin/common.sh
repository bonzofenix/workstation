#!/bin/bash
exec >&2

if [[ "${DEBUG}" == "true" ]]; then
  set -x
  echo "Environment Variables:"
  env
fi


function log() {
  green='\033[0;32m'
  reset='\033[0m'

  echo -e "${green}$1${reset}"
}


function log_stderr() {
  purple='\033[0;35m'
  reset='\033[0m'

  echo -e "${purple}$1${reset}" >&2
}

function error() {
  red='\033[0;31m'
  reset='\033[0m'

  echo -e "${green}$1${reset}"
}

function check_if_exists(){
  ERROR_MSG=$1
  CONTENT=$2

  if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
    echo $ERROR_MSG
    exit 1
  fi
}

function check_if_file_exists(){
  FILE=$1

  if [[ ! -f $FILE ]]; then
    log "Required file $FILE not found..."
    exit 1
  fi
}
