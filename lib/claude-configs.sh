#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"

# relink points an existing symlink at a new source. link_if_missing leaves an
# existing link alone, which strands links whose source moved (memory used to
# live in this repo). Real files and directories are still never touched.
relink() {
  local source="$1" target="$2" name="$3"
  if [ -L "$target" ] && [ "$(readlink "$target")" != "$source" ]; then
    ln -fns "$source" "$target"
    log_success "Relinked $name"
  else
    link_if_missing "$source" "$target" "$name"
  fi
}

function main() {
  local workstation_dir
  workstation_dir="$(cd "$(dirname "$0")/.." && pwd -P)"
  local source_dir="$workstation_dir/assets/claude"
  local target_dir="$HOME/.claude"
  local memory_dir="${MEMORY_DIR:-$HOME/workspace/memory}"

  log_section "Claude Code Configs"

  mkdir -p "$target_dir/hooks"

  link_if_missing "$source_dir/settings.json" "$target_dir/settings.json" "settings.json"
  link_if_missing "$source_dir/statusline-command.sh" "$target_dir/statusline-command.sh" "statusline"
  # Every hook, not a hand-picked list: settings.json references them all, and
  # a hook it names but that was never linked fails on every tool call.
  local hook_dir
  for hook_dir in "$source_dir"/hooks/*/; do
    [ -d "$hook_dir" ] || continue
    link_if_missing "${hook_dir%/}" "$target_dir/hooks/$(basename "$hook_dir")" "hooks/$(basename "$hook_dir")"
  done

  # Download peon sounds if not present
  local sounds_dir="$source_dir/hooks/peon-ping/packs/peon/sounds"
  if [ ! -d "$sounds_dir" ] || [ -z "$(ls -A "$sounds_dir" 2>/dev/null)" ]; then
    log_step "Downloading peon sounds"
    "$source_dir/hooks/peon-ping/scripts/download-sounds.sh" "$source_dir/hooks/peon-ping" peon \
      || log_warning "Failed to download sounds, run manually later"
  else
    log_success "Peon sounds already present"
  fi

  log_step "Installing Claude skills and plugins"
  # Skills and plugins are declared in the Skillfile of bonzofenix/skills
  # (plus an optional private Skillfile.local in the memory repo).
  # It also clones the memory repo on a fresh machine, which is why memory is
  # linked after it rather than before.
  local bundle_rc=0
  "$workstation_dir/bin/skills-bundle" install || bundle_rc=$?

  # Global memory lives in the private memory repo (bonzofenix/memory).
  # Without it (anyone but its owner) memory is simply left unlinked.
  if [ -d "$memory_dir/memory" ]; then
    local global_memory_target="$HOME/.claude/projects/${HOME//\//-}"
    mkdir -p "$global_memory_target"
    relink "$memory_dir/memory" "$global_memory_target/memory" "global memory"
  else
    log_warning "No private memory repo at $memory_dir; skipping memory link"
  fi

  # skills-bundle failures fail this step (and `make`): a warning scrolled
  # past above a green "configured" line is how partial installs went
  # unnoticed.
  if [ "$bundle_rc" -ne 0 ]; then
    log_warning "skills-bundle reported failures (listed above); fix and rerun: skills-bundle install"
    return 1
  fi

  log_success "Claude Code configs configured"
}

main
