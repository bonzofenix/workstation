exec >&2

if [[ "${DEBUG}" == "true" ]]; then
  set -x
  echo "Environment Variables:"
  env
fi

function add_to_profile(){
  local profile=~/.zprofile
  local profile_changed="false"

  for profile_line in "$@"; do
    if ! grep -q "${profile_line//\"/\\\"}" $profile; then
      echo $profile_line >> $profile
      profile_changed="true"
    fi
  done

  [ "$profile_changed" == "true" ] && echo >> $profile
  return 0
}

function say(){
  echo '======> :heart: $1 :candy:' | gum format -t emoji
}
