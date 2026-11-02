#!/usr/bin/env bash

_update_refuse() {
  log_error "$1 Update was not performed."
  return 1
}

_update_checkout_head() {
  git -C "$1" rev-parse --verify HEAD^{commit} 2>/dev/null
}

_update_remote_head() {
  local remote_line remote_sha remote_ref
  if ! remote_line="$(git -C "$1" ls-remote --exit-code "$2" refs/heads/main 2>/dev/null)"; then
    return 1
  fi
  read -r remote_sha remote_ref <<< "$remote_line"
  if [[ "$remote_ref" != "refs/heads/main" || ! "$remote_sha" =~ ^[[:xdigit:]]{40}([[:xdigit:]]{24})?$ ]]; then
    return 1
  fi
  printf '%s\n' "$remote_sha"
}

_update_canonical_origin() {
  local configured_url effective_url
  if ! configured_url="$(git -C "$1" config --get remote.origin.url 2>/dev/null)" || [[ "$configured_url" != "$2" ]]; then
    _update_refuse "The installation's origin is not the canonical GitHub repository."
    return 1
  fi
  if ! effective_url="$(git -C "$1" remote get-url origin 2>/dev/null)" || [[ "$effective_url" != "$2" ]]; then
    _update_refuse "Git URL rewriting redirects origin away from the canonical GitHub repository."
    return 1
  fi
}

_update_prompt_confirmation() {
  local answer
  if ! IFS= read -r -p "Update chien-dev to $1? [y/N]: " answer; then
    return 2
  fi
  [[ "$answer" =~ ^[Yy]$ ]] && return 0
  return 1
}

_update_safe_checkout() {
  local checkout="$1" canonical_url="$2" branch state
  if ! branch="$(git -C "$checkout" symbolic-ref --quiet --short HEAD 2>/dev/null)" || [[ "$branch" != "main" ]]; then
    _update_refuse "The installation must be on local branch main."
    return 1
  fi
  if ! _update_canonical_origin "$checkout" "$canonical_url"; then
    return 1
  fi
  if ! state="$(git -C "$checkout" status --porcelain --untracked-files=all 2>/dev/null)"; then
    _update_refuse "Unable to determine whether the installation is clean."
    return 1
  fi
  if [[ -n "$state" ]]; then
    _update_refuse "The installation has local changes or untracked files."
    return 1
  fi
}

do_update() {
  local canonical_url="https://github.com/pong1013/dev-environment-setup.git"
  local checkout checkout_top local_sha remote_sha fetched_sha confirmation_status

  if [[ "$#" -ne 0 ]]; then
    _update_refuse "Usage: chien-dev update (no options)."
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    _update_refuse "Git is unavailable; unable to determine the installed version."
    return 1
  fi

  checkout="$(cd "${SCRIPT_DIR}/.." && pwd -P)"
  if ! checkout_top="$(git -C "$checkout" rev-parse --show-toplevel 2>/dev/null)" ||
     [[ "$checkout_top" != "$checkout" ]] ||
     ! git -C "$checkout" ls-files --error-unmatch -- scripts/chien-dev >/dev/null 2>&1; then
    _update_refuse "The running executable is not in a chien-dev Git checkout; unable to determine its version."
    return 1
  fi

  if ! _update_canonical_origin "$checkout" "$canonical_url"; then
    return 1
  fi
  if ! local_sha="$(_update_checkout_head "$checkout")"; then
    _update_refuse "Unable to determine the installed commit."
    return 1
  fi
  if ! remote_sha="$(_update_remote_head "$checkout" "$canonical_url")"; then
    _update_refuse "Unable to determine GitHub main's commit (check your connection)."
    return 1
  fi

  if [[ "$local_sha" == "$remote_sha" ]]; then
    log_info "chien-dev is up to date at ${local_sha} (GitHub main: ${remote_sha})."
    return 0
  fi
  log_info "Installed commit: ${local_sha}; GitHub main: ${remote_sha}."

  if ! _update_safe_checkout "$checkout" "$canonical_url"; then
    return 1
  fi
  if ! git -C "$checkout" fetch --no-tags "$canonical_url" refs/heads/main >/dev/null 2>&1 ||
     ! fetched_sha="$(git -C "$checkout" rev-parse --verify FETCH_HEAD^{commit} 2>/dev/null)" ||
     [[ "$fetched_sha" != "$remote_sha" ]]; then
    _update_refuse "Unable to fetch the checked GitHub main commit."
    return 1
  fi
  if ! git -C "$checkout" merge-base --is-ancestor "$local_sha" "$remote_sha"; then
    _update_refuse "GitHub main cannot fast-forward this installation."
    return 1
  fi
  log_info "chien-dev is behind GitHub main."
  if [[ ! -t 0 || ! -t 1 ]]; then
    _update_refuse "An interactive terminal is required to confirm the update."
    return 1
  fi
  confirmation_status=0
  _update_prompt_confirmation "$remote_sha" || confirmation_status=$?
  case "$confirmation_status" in
    0) ;;
    1)
      log_info "Update declined. The installation remains behind GitHub main at ${local_sha}."
      return 0
      ;;
    *)
      _update_refuse "Unable to read update confirmation."
      return 1
      ;;
  esac

  if ! _update_safe_checkout "$checkout" "$canonical_url" ||
     [[ "$(_update_checkout_head "$checkout")" != "$local_sha" ]] ||
     [[ "$(_update_remote_head "$checkout" "$canonical_url")" != "$remote_sha" ]]; then
    _update_refuse "The installation or GitHub main changed during confirmation."
    return 1
  fi
  if ! git -C "$checkout" merge-base --is-ancestor "$local_sha" "$remote_sha" ||
     ! git -C "$checkout" merge --ff-only --no-edit "$remote_sha" >/dev/null 2>&1; then
    _update_refuse "The fast-forward update could not be completed safely."
    return 1
  fi
  log_success "chien-dev updated from ${local_sha} to ${remote_sha}."
}
