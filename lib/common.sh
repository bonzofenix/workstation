exec >&2

if [[ "${DEBUG}" == "true" ]]; then
  set -x
  echo "Environment Variables:"
  env
fi

function add_to_rc(){
  local profile=~/.zshrc
  add_to_file $profile "$@"
  return 0
}

function add_to_profile(){
  local profile=~/.zprofile
  add_to_file $profile "$@"
  return 0
}

# write a generic function that adds a line to a file if it doesn't exist
function add_to_file(){
  local file=$1
  local file_changed="false"

  for file_line in "${@:2}"; do
    if ! grep -q "${file_line//\"/\\\"}" $file; then
      echo $file_line >> $file
      file_changed="true"
    fi
  done

  [ "$file_changed" == "true" ] && echo >> $file
  return 0
}

function say(){
  echo '======> :heart: $1 :candy:' | gum format -t emoji
}
