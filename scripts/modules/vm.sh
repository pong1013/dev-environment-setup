#!/usr/bin/env bash

ensure_multipass() {
  if ! command -v multipass >/dev/null 2>&1; then
    log_error "multipass not found. Please install it first"
    exit 1
  fi
}

vm_launch() {
  local name="$1"
  local cloud_init_file="$2"
  local cpus="${3:-2}"
  local memory="${4:-2G}"
  local disk="${5:-10G}"
  
  log_info "Launching VM: ${name} (CPUs: ${cpus}, RAM: ${memory}, Disk: ${disk})..."
  multipass launch --name "${name}" \
                   --cloud-init "${cloud_init_file}" \
                   --cpus "${cpus}" \
                   --memory "${memory}" \
                   --disk "${disk}"
}

get_host_resources() {
  local total_mem_gb
  local total_cpus
  local free_disk_gb

  if [[ "$(uname)" == "Darwin" ]]; then
    # Mac
    total_mem_gb=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))
    total_cpus=$(sysctl -n hw.ncpu)
    free_disk_gb=$(df -h / | awk 'NR==2 {print $4}' | sed 's/Gi//')
  else
    # Linux
    total_mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    total_cpus=$(nproc)
    free_disk_gb=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
  fi

  echo "Host Resources: CPU: ${total_cpus} cores, RAM: ${total_mem_gb}GB, Disk Free: ~${free_disk_gb}GB" >&2
}

vm_get_ip() {
  local name="$1"
  multipass info "${name}" --format json | jq -r ".info.\"${name}\".ipv4[0]"
}

vm_get_status() {
  local name="$1"
  multipass info "${name}" --format json | jq -r ".info.\"${name}\".state"
}

vm_stop() {
  local name="$1"
  log_info "Stopping VM: ${name}..."
  multipass stop "${name}"
}

vm_delete() {
  local name="$1"
  log_info "Deleting VM: ${name}..."
  multipass delete "${name}"
  multipass purge
}

ensure_ssh_key() {
  local ssh_key_file=""
  local pub_key=""

  # Search for existing keys
  if [[ -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    ssh_key_file="${HOME}/.ssh/id_ed25519.pub"
  elif [[ -f "${HOME}/.ssh/id_rsa.pub" ]]; then
    ssh_key_file="${HOME}/.ssh/id_rsa.pub"
  fi

  if [[ -n "${ssh_key_file}" ]]; then
    pub_key=$(cat "${ssh_key_file}")
    log_info "Using existing SSH public key: ${ssh_key_file}" >&2
    echo "${pub_key}"
    return 0
  fi

  # No key found, ask to generate
  log_warn "No SSH public key found in ~/.ssh/ (id_ed25519.pub or id_rsa.pub)." >&2
  if prompt_yes_no "Would you like to generate a new SSH key pair now?" "y"; then
    log_info "Generating new SSH key (Ed25519)..." >&2
    ssh-keygen -t ed25519 -N "" -f "${HOME}/.ssh/id_ed25519"
    log_success "Generated: ~/.ssh/id_ed25519.pub" >&2
    cat "${HOME}/.ssh/id_ed25519.pub"
    return 0
  else
    log_error "SSH key is required for VM access. Please create one manually and try again." >&2
    exit 1
  fi
}
