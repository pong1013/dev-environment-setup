#!/usr/bin/env bash

# _parse_lang <comma_list> sets include_go/node/python/java/php locals.
# Caller must have those locals declared before calling.
_parse_lang() {
  local raw="$1"
  local item
  IFS=',' read -r -a _lang_arr <<< "${raw}"
  for item in "${_lang_arr[@]}"; do
    item="$(echo "${item}" | tr -d '[:space:]')"
    case "${item}" in
      go)     include_go="true" ;;
      node)   include_node="true" ;;
      python) include_python="true" ;;
      java)   include_java="true" ;;
      php)    include_php="true" ;;
      *)      log_warn "Unknown language '${item}', skipping." ;;
    esac
  done
}

_parse_db() {
  local raw="$1"
  local item
  IFS=',' read -r -a _db_arr <<< "${raw}"
  for item in "${_db_arr[@]}"; do
    item="$(echo "${item}" | tr -d '[:space:]')"
    case "${item}" in
      postgres|postgresql) include_pg="true" ;;
      mysql)               include_mysql="true" ;;
      mongodb)             include_mongodb="true" ;;
      none)                ;;
      *)                   log_warn "Unknown database '${item}', skipping." ;;
    esac
  done
}

_parse_broker() {
  local raw="$1"
  local item
  IFS=',' read -r -a _broker_arr <<< "${raw}"
  for item in "${_broker_arr[@]}"; do
    item="$(echo "${item}" | tr -d '[:space:]')"
    case "${item}" in
      redis)    include_redis="true" ;;
      rabbitmq) include_rabbitmq="true" ;;
      kafka)    include_kafka="true" ;;
      none)     ;;
      *)        log_warn "Unknown broker '${item}', skipping." ;;
    esac
  done
}

do_create() {
  local env_name
  local include_go="false"
  local include_node="false"
  local include_python="false"
  local include_java="false"
  local include_php="false"
  local frontend_framework="none"
  local include_pg="false"
  local include_mysql="false"
  local include_mongodb="false"
  local include_redis="false"
  local include_rabbitmq="false"
  local include_kafka="false"
  local os_version="22.04"
  local go_version="1.23.0"
  local node_version="20"
  local python_version="system"
  local java_version="17"
  local php_version="system"
  local pg_version="16"
  local mysql_version="8"
  local mongodb_version="7"
  local redis_version="7"
  local rabbitmq_version="3-management"
  local kafka_version="3.7.0"
  local env_dir
  local config_file
  local devcontainer_dir
  local compose_file
  local cloud_init_file
  local env_type="${ENV:-}"
  
  # VM specific defaults
  local vm_cpus="${VM_CPUS:-2}"
  local vm_mem="${VM_MEM:-2G}"
  local vm_disk="${VM_DISK:-10G}"

  env_name="$(resolve_env_name "${env_name_arg}")"
  validate_env_name "${env_name}"

  # ── Non-interactive mode ──────────────────────────────────────────────────
  if [[ -n "${LANGS:-}${FRONTEND:-}${DB:-}${BROKER:-}${OS:-}${ENV:-}" ]]; then
    log_info "Non-interactive mode: reading from environment variables."
    env_type="${ENV:-devcontainer}"
    os_version="${OS:-22.04}"
    [[ -n "${LANGS:-}" ]]     && _parse_lang    "${LANGS}"
    [[ -n "${FRONTEND:-}" ]] && frontend_framework="$(echo "${FRONTEND}" | tr '[:upper:]' '[:lower:]')"
    [[ -n "${DB:-}" ]]       && _parse_db      "${DB}"
    [[ -n "${BROKER:-}" ]]   && _parse_broker  "${BROKER}"

    if [[ "${frontend_framework}" != "none" ]]; then
      include_node="true"
    fi
    go_version="${GO_VER:-${go_version}}"
    node_version="${NODE_VER:-${node_version}}"
    python_version="${PYTHON_VER:-${python_version}}"
    java_version="${JAVA_VER:-${java_version}}"
    php_version="${PHP_VER:-${php_version}}"
    pg_version="${PG_VER:-${pg_version}}"
    mysql_version="${MYSQL_VER:-${mysql_version}}"
    mongodb_version="${MONGODB_VER:-${mongodb_version}}"
    redis_version="${REDIS_VER:-${redis_version}}"
    rabbitmq_version="${RABBITMQ_VER:-${rabbitmq_version}}"
    kafka_version="${KAFKA_VER:-${kafka_version}}"

  # ── Interactive mode ──────────────────────────────────────────────────────
  else
    print_header
    
    # First, ask for environment type if not specified
    if [[ -z "${env_type}" ]]; then
      local env_option
      env_option="$(prompt_choice "Select Environment Type:" "DevContainer (Docker)" "Virtual Machine (Multipass)")"
      if [[ "${env_option}" == "Virtual Machine (Multipass)" ]]; then
        env_type="vm"
      else
        env_type="devcontainer"
      fi
    fi

    local os_option
    os_option="$(prompt_choice "Select OS version:" "ubuntu:22.04" "ubuntu:24.04")"
    os_version="${os_option#ubuntu:}"

    # For VM, we skip language/db/broker selection for Step 1
    if [[ "${env_type}" == "vm" ]]; then
      echo ""
      get_host_resources
      echo "--- VM Resource Configuration ---"
      read -r -p "Enter CPU cores (default 2): " input_cpus
      vm_cpus="${input_cpus:-2}"
      read -r -p "Enter Memory (e.g. 2G, 4G) (default 2G): " input_mem
      vm_mem="${input_mem:-2G}"
      read -r -p "Enter Disk Size (e.g. 10G, 20G) (default 10G): " input_disk
      vm_disk="${input_disk:-10G}"
      echo ""
    else
      local language_options_raw
      language_options_raw="$(prompt_multi_choice "Select Backend Language(s):" "Go" "Node.js" "Python" "Java" "PHP")"
      while IFS= read -r language_option; do
        case "${language_option}" in
          Go)     include_go="true" ;;
          Node.js) include_node="true" ;;
          Python) include_python="true" ;;
          Java)   include_java="true" ;;
          PHP)    include_php="true" ;;
        esac
      done <<< "${language_options_raw}"

      local frontend_option
      frontend_option="$(prompt_choice "Select Frontend Framework:" "None" "React" "Vue")"
      if [[ "${frontend_option}" != "None" ]]; then
        frontend_framework="$(echo "${frontend_option}" | tr '[:upper:]' '[:lower:]')"
        include_node="true"
      fi

      local db_options_raw
      db_options_raw="$(prompt_multi_choice "Select Database(s) (e.g. 1+2, or 4 for None):" "PostgreSQL" "MySQL" "MongoDB" "None")"
      while IFS= read -r db_option; do
        case "${db_option}" in
          PostgreSQL) include_pg="true" ;;
          MySQL)      include_mysql="true" ;;
          MongoDB)    include_mongodb="true" ;;
        esac
      done <<< "${db_options_raw}"

      local broker_options_raw
      broker_options_raw="$(prompt_multi_choice "Select Cache/Message Broker(s) (e.g. 1+2, or 4 for None):" "Redis" "RabbitMQ" "Kafka" "None")"
      while IFS= read -r broker_option; do
        case "${broker_option}" in
          Redis)    include_redis="true" ;;
          RabbitMQ) include_rabbitmq="true" ;;
          Kafka)    include_kafka="true" ;;
        esac
      done <<< "${broker_options_raw}"
    fi
  fi

  env_dir="$(env_dir_for "${env_name}")"
  config_file="$(config_file_for "${env_name}")"
  mkdir -p "${env_dir}"

  if [[ "${env_type}" == "vm" ]]; then
    ensure_multipass
    local ssh_key
    # ensure_ssh_key handles interactive generation if needed
    ssh_key=$(ensure_ssh_key)
    
    cloud_init_file="${env_dir}/cloud-init.yaml"
    render_cloud_init "${cloud_init_file}" "${env_name}" "${ssh_key}"
    vm_launch "${env_name}" "${cloud_init_file}" "${vm_cpus}" "${vm_mem}" "${vm_disk}"
    
    # Render config with minimal options for VM
    render_config "${config_file}" "${env_name}" "${os_version}" "false" "false" "false" "false" "false" "none" "false" "false" "false" "false" "false" "false" "" "" "" "" "" "" "" "" "" "" "" "5432" "3306" "27017" "6379" "5672" "9092" "vm"
  else
    devcontainer_dir="$(devcontainer_dir_for "${env_name}")"
    compose_file="$(compose_file_for "${env_name}")"
    
    local pg_host_port=5432
    local mysql_host_port=3306
    local mongodb_host_port=27017
    local redis_host_port=6379
    local rabbitmq_host_port=5672
    local kafka_host_port=9092

    [[ "${include_pg}" == "true" ]] && pg_host_port=$(find_available_port 5432)
    [[ "${include_mysql}" == "true" ]] && mysql_host_port=$(find_available_port 3306)
    [[ "${include_mongodb}" == "true" ]] && mongodb_host_port=$(find_available_port 27017)
    [[ "${include_redis}" == "true" ]] && redis_host_port=$(find_available_port 6379)
    [[ "${include_rabbitmq}" == "true" ]] && rabbitmq_host_port=$(find_available_port 5672)
    [[ "${include_kafka}" == "true" ]] && kafka_host_port=$(find_available_port 9092)

    render_config "${config_file}" "${env_name}" "${os_version}" "${include_go}" "${include_node}" "${include_python}" "${include_java}" "${include_php}" "${frontend_framework}" "${include_pg}" "${include_mysql}" "${include_mongodb}" "${include_redis}" "${include_rabbitmq}" "${include_kafka}" "${go_version}" "${node_version}" "${python_version}" "${java_version}" "${php_version}" "${pg_version}" "${mysql_version}" "${mongodb_version}" "${redis_version}" "${rabbitmq_version}" "${kafka_version}" "${pg_host_port}" "${mysql_host_port}" "${mongodb_host_port}" "${redis_host_port}" "${rabbitmq_host_port}" "${kafka_host_port}" "devcontainer"
    render_devcontainer "${devcontainer_dir}" "${env_name}" "${os_version}" "${include_go}" "${include_node}" "${include_python}" "${include_java}" "${include_php}" "${frontend_framework}" "${go_version}" "${node_version}" "${python_version}" "${java_version}" "${php_version}"
    render_compose "${compose_file}" "${ROOT_DIR}" "${include_pg}" "${include_mysql}" "${include_mongodb}" "${include_redis}" "${include_rabbitmq}" "${include_kafka}" "${pg_version}" "${mysql_version}" "${mongodb_version}" "${redis_version}" "${rabbitmq_version}" "${kafka_version}" "${pg_host_port}" "${mysql_host_port}" "${mongodb_host_port}" "${redis_host_port}" "${rabbitmq_host_port}" "${kafka_host_port}"
  fi

  echo ""
  log_success "Generated environment: ${env_name} (${env_type})"
  echo "  - ${config_file}"
  if [[ "${env_type}" == "vm" ]]; then
    local vm_ip=$(vm_get_ip "${env_name}")
    echo "  - VM IP: ${vm_ip}"
    echo "  - Login: ssh ubuntu@${vm_ip}"
  else
    echo "  - ${devcontainer_dir}/Dockerfile"
    echo "  - ${devcontainer_dir}/devcontainer.json"
    echo "  - ${compose_file}"
  fi
}
