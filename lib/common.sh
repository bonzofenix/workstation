# shellcheck shell=bash
# Sourced by the lib/*.sh scripts, so it has no shebang of its own.

exec >&2

if [[ "${DEBUG}" == "true" ]]; then
  set -x
  echo "Environment Variables:"
  env
fi

_has_gum() { command -v gum >/dev/null 2>&1; }

log_section() {
  if _has_gum; then
    echo
    gum style --foreground 212 --bold --border-foreground 212 --border normal --padding "0 1" " $* "
    echo
  else
    echo; echo "==> $*"; echo
  fi
}

log_step() {
  if _has_gum; then
    gum log --level info "$@"
  else
    echo "  • $*"
  fi
}

log_success() {
  if _has_gum; then
    gum log --level info "$(gum style --foreground 2 "✓") $*"
  else
    echo "  ✓ $*"
  fi
}

log_warning() {
  if _has_gum; then
    gum log --level warn "$@"
  else
    echo "  ⚠ $*"
  fi
}

log_error() {
  if _has_gum; then
    gum log --level error "$@"
  else
    echo "  ✗ $*" >&2
  fi
}

run_with_spin() {
  local title="$1"; shift
  if _has_gum; then
    # --show-error: without it a failing command's output is swallowed.
    gum spin --spinner dot --show-error --title "$title" -- "$@"
  else
    echo "  • $title"
    "$@"
  fi
}

# Installs the plugins tmux.conf lists; tpm skips any already present.
# Loud on failure: without resurrect and continuum nothing is saved, and
# that only shows after a reboot restores nothing.
install_tmux_plugins() {
  if ! run_with_spin "Installing tmux plugins..." ~/.tmux/plugins/tpm/bin/install_plugins; then
    log_error "tmux plugins failed to install; sessions will not survive a reboot. Rerun ~/.tmux/plugins/tpm/bin/install_plugins to see why"
    return 1
  fi
}

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

function add_to_host(){
  local profile=/etc/hosts
  add_to_file $profile "$@"
  return 0
}

# write a generic function that adds a line to a file if it doesn't exist
function add_to_file(){
  local file=$1
  local file_changed="false"

  for file_line in "${@:2}"; do
    # -F: profile lines are shell code, not regexes. As a regex a line like
    # [[ ... $- == *i* ]] is invalid; grep exits 2, `!` reads that as missing,
    # and the line is appended on every run. Still a substring match (no -x).
    if ! grep -qF -- "$file_line" "$file"; then
      echo "$file_line" >> "$file"
      file_changed="true"
    fi
  done

  [ "$file_changed" == "true" ] && echo >> "$file"
  return 0
}

# Create a symlink if target doesn't exist, report status
link_if_missing() {
  local source="$1"
  local target="$2"
  local name="$3"

  if [ -L "$target" ]; then
    log_success "$name already linked"
  elif [ -e "$target" ]; then
    log_warning "$target exists and is not a symlink, skipping"
  else
    ln -s "$source" "$target"
    log_success "Linked $name"
  fi
}


