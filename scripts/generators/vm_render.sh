#!/usr/bin/env bash

render_cloud_init() {
  local target_file="$1"
  local env_name="$2"
  local ssh_key="$3"

  if [[ -z "${ssh_key}" ]]; then
    log_error "No SSH key provided for cloud-init. VM will not be accessible."
    exit 1
  fi

  cat > "${target_file}" <<EOF
#cloud-config
hostname: ${env_name}
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_key}

package_update: true
packages:
  - curl
  - wget
  - git
  - apt-transport-https
  - ca-certificates
  - software-properties-common

runcmd:
  - echo "VM for ${env_name} is ready." > /etc/motd
EOF
}
