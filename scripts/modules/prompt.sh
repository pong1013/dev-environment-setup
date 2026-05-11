#!/usr/bin/env bash

print_header() {
  echo "=============================================="
  echo " chien-dev | Dev Environment Setup"
  echo "=============================================="
}

resolve_env_name() {
  local provided_name="$1"
  if [[ -n "${provided_name}" ]]; then
    echo "${provided_name}"
    return
  fi
  local prompted_name
  read -r -p "Enter environment name (e.g. go-dev, node-dev): " prompted_name
  echo "${prompted_name}"
}

prompt_choice() {
  local prompt="$1"
  shift
  local options=("$@")
  local i
  local choice

  echo "${prompt}" >&2
  for ((i=0; i<${#options[@]}; i++)); do
    echo "  $((i+1))) ${options[$i]}" >&2
  done

  while true; do
    read -r -p "Enter option number: " choice >&2
    if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      echo "${options[$((choice-1))]}"
      return
    fi
    echo "Invalid option, please try again." >&2
  done
}

prompt_multi_choice() {
  local prompt="$1"
  shift
  local options=("$@")
  local i
  local input
  local idx
  local token
  local -a selected=()
  local -a numbers=()
  local seen_tokens=""

  echo "${prompt}" >&2
  for ((i=0; i<${#options[@]}; i++)); do
    echo "  $((i+1))) ${options[$i]}" >&2
  done

  while true; do
    read -r -p "Enter one or more numbers (e.g. 1+2): " input >&2
    input="${input// /}"
    IFS='+' read -r -a numbers <<< "${input}"
    selected=()
    seen_tokens=""
    local valid="true"

    if [[ ${#numbers[@]} -eq 0 || -z "${numbers[0]}" ]]; then
      valid="false"
    fi

    if [[ "${valid}" == "true" ]]; then
      for token in "${numbers[@]}"; do
        if [[ ! "${token}" =~ ^[0-9]+$ ]]; then
          valid="false"
          break
        fi
        idx=$((token-1))
        if (( idx < 0 || idx >= ${#options[@]} )); then
          valid="false"
          break
        fi
        if [[ ",${seen_tokens}," != *",${token},"* ]]; then
          selected+=("${options[$idx]}")
          seen_tokens="${seen_tokens},${token}"
        fi
      done
    fi

    if [[ "${valid}" == "true" && ${#selected[@]} -gt 0 ]]; then
      printf "%s\n" "${selected[@]}"
      return
    fi

    echo "Invalid input, please use numbers like 1 or 1+2." >&2
  done
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local answer

  if [[ "${default}" == "y" ]]; then
    read -r -p "${prompt} [Y/n]: " answer
    answer="${answer:-Y}"
  else
    read -r -p "${prompt} [y/N]: " answer
    answer="${answer:-N}"
  fi

  [[ "${answer}" =~ ^[Yy]$ ]]
}
