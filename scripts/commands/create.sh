#!/usr/bin/env bash

do_create() {
  print_header
  local env_name
  local os_option
  local language_options_raw
  local language_option
  local include_go="false"
  local include_node="false"
  local include_pg="false"
  local include_redis="false"
  local os_version
  local env_dir
  local config_file
  local devcontainer_dir
  local compose_file

  env_name="$(resolve_env_name "${env_name_arg}")"
  validate_env_name "${env_name}"
  os_option="$(prompt_choice "Select OS version:" "ubuntu:22.04" "ubuntu:24.04")"
  language_options_raw="$(prompt_multi_choice "Select language stack(s):" "Go" "Node")"
  while IFS= read -r language_option; do
    case "${language_option}" in
      Go)
        include_go="true"
        ;;
      Node)
        include_node="true"
        ;;
    esac
  done <<< "${language_options_raw}"

  if prompt_yes_no "Include PostgreSQL service?" "y"; then
    include_pg="true"
  fi
  if prompt_yes_no "Include Redis service?" "y"; then
    include_redis="true"
  fi

  os_version="${os_option#ubuntu:}"

  env_dir="$(env_dir_for "${env_name}")"
  config_file="$(config_file_for "${env_name}")"
  devcontainer_dir="$(devcontainer_dir_for "${env_name}")"
  compose_file="$(compose_file_for "${env_name}")"
  mkdir -p "${env_dir}"

  render_config "${config_file}" "${env_name}" "${os_version}" "${include_go}" "${include_node}" "${include_pg}" "${include_redis}"
  render_devcontainer "${devcontainer_dir}" "${env_name}" "${os_version}" "${include_go}" "${include_node}"
  render_compose "${compose_file}" "${ROOT_DIR}" "${include_pg}" "${include_redis}"

  echo ""
  echo "Generated environment: ${env_name}"
  echo "  - ${config_file}"
  echo "  - ${devcontainer_dir}/Dockerfile"
  echo "  - ${devcontainer_dir}/devcontainer.json"
  echo "  - ${compose_file}"
}
