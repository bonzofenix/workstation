exec >&2

if [[ "${DEBUG}" == "true" ]]; then
  set -x
  echo "Environment Variables:"
  env
fi

function add_to_profile(){
  local profile=""
  local profile_changed="false"

  if [[ ! -f '~/.bash_profile' ]]; then
    profile=~/.bash_profile
  else
    profile=~/.zprofile
  fi

  # Add empty line to profile

  for profile_line in "$@"; do
    if ! grep -q "${profile_line//\"/\\\"}" $profile; then
      echo $profile_line >> $profile
      profile_changed="true"
    fi
  done

  [ "$profile_changed" == "true" ] && echo >> $profile
  return 0
}
