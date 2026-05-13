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
  local os_version
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

  env_name="$(resolve_env_name "${env_name_arg}")"
  validate_env_name "${env_name}"

  # ── Non-interactive mode ──────────────────────────────────────────────────
  if [[ -n "${LANGS:-}${FRONTEND:-}${DB:-}${BROKER:-}${OS:-}" ]]; then
    log_info "Non-interactive mode: reading from environment variables."

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

    local os_option
    local language_options_raw
    local language_option
    local frontend_option
    local db_options_raw
    local db_option
    local broker_options_raw
    local broker_option

    os_option="$(prompt_choice "Select OS version:" "ubuntu:22.04" "ubuntu:24.04")"
    os_version="${os_option#ubuntu:}"

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

    frontend_option="$(prompt_choice "Select Frontend Framework:" "None" "React" "Vue")"
    if [[ "${frontend_option}" != "None" ]]; then
      frontend_framework="$(echo "${frontend_option}" | tr '[:upper:]' '[:lower:]')"
      include_node="true"
    fi

    db_options_raw="$(prompt_multi_choice "Select Database(s) (e.g. 1+2, or 4 for None):" "PostgreSQL" "MySQL" "MongoDB" "None")"
    while IFS= read -r db_option; do
      case "${db_option}" in
        PostgreSQL) include_pg="true" ;;
        MySQL)      include_mysql="true" ;;
        MongoDB)    include_mongodb="true" ;;
      esac
    done <<< "${db_options_raw}"

    broker_options_raw="$(prompt_multi_choice "Select Cache/Message Broker(s) (e.g. 1+2, or 4 for None):" "Redis" "RabbitMQ" "Kafka" "None")"
    while IFS= read -r broker_option; do
      case "${broker_option}" in
        Redis)    include_redis="true" ;;
        RabbitMQ) include_rabbitmq="true" ;;
        Kafka)    include_kafka="true" ;;
      esac
    done <<< "${broker_options_raw}"

    local specify_versions="false"
    if prompt_yes_no "Do you want to specify custom versions for the selected tools? (Default uses LTS/latest)" "n"; then
      specify_versions="true"
    fi

    if [[ "${specify_versions}" == "true" ]]; then
      if [[ "${include_go}" == "true" ]]; then
        go_version="$(prompt_choice "Select Go version:" "1.23.0" "1.22.0" "Other")"
        if [[ "${go_version}" == "Other" ]]; then
          read -r -p "Enter Go version (e.g. 1.21.0) [default: 1.23.0]: " go_version
          go_version="${go_version:-1.23.0}"
        fi
      fi
      if [[ "${include_node}" == "true" ]]; then
        node_version="$(prompt_choice "Select Node.js version:" "22" "20" "18" "Other")"
        if [[ "${node_version}" == "Other" ]]; then
          read -r -p "Enter Node.js version (e.g. 16) [default: 20]: " node_version
          node_version="${node_version:-20}"
        fi
      fi
      if [[ "${include_python}" == "true" ]]; then
        python_version="$(prompt_choice "Select Python version:" "3.12" "3.10" "3.8" "Other")"
        if [[ "${python_version}" == "Other" ]]; then
          read -r -p "Enter Python version (e.g. 3.9) [default: system]: " python_version
          python_version="${python_version:-system}"
        fi
      fi
      if [[ "${include_java}" == "true" ]]; then
        java_version="$(prompt_choice "Select Java version:" "21" "17" "11" "Other")"
        if [[ "${java_version}" == "Other" ]]; then
          read -r -p "Enter Java version (e.g. 8) [default: 17]: " java_version
          java_version="${java_version:-17}"
        fi
      fi
      if [[ "${include_php}" == "true" ]]; then
        php_version="$(prompt_choice "Select PHP version:" "8.3" "8.2" "8.1" "Other")"
        if [[ "${php_version}" == "Other" ]]; then
          read -r -p "Enter PHP version (e.g. 7.4) [default: system]: " php_version
          php_version="${php_version:-system}"
        fi
      fi
      if [[ "${include_pg}" == "true" ]]; then
        pg_version="$(prompt_choice "Select PostgreSQL version:" "16" "15" "14" "Other")"
        if [[ "${pg_version}" == "Other" ]]; then
          read -r -p "Enter PostgreSQL version (e.g. 13) [default: 16]: " pg_version
          pg_version="${pg_version:-16}"
        fi
      fi
      if [[ "${include_mysql}" == "true" ]]; then
        mysql_version="$(prompt_choice "Select MySQL version:" "8.4" "8.0" "Other")"
        if [[ "${mysql_version}" == "Other" ]]; then
          read -r -p "Enter MySQL version (e.g. 5.7) [default: 8]: " mysql_version
          mysql_version="${mysql_version:-8}"
        fi
      fi
      if [[ "${include_mongodb}" == "true" ]]; then
        mongodb_version="$(prompt_choice "Select MongoDB version:" "7" "6" "Other")"
        if [[ "${mongodb_version}" == "Other" ]]; then
          read -r -p "Enter MongoDB version (e.g. 5) [default: 7]: " mongodb_version
          mongodb_version="${mongodb_version:-7}"
        fi
      fi
      if [[ "${include_redis}" == "true" ]]; then
        redis_version="$(prompt_choice "Select Redis version:" "7" "6" "Other")"
        if [[ "${redis_version}" == "Other" ]]; then
          read -r -p "Enter Redis version (e.g. 5) [default: 7]: " redis_version
          redis_version="${redis_version:-7}"
        fi
      fi
      if [[ "${include_rabbitmq}" == "true" ]]; then
        rabbitmq_version="$(prompt_choice "Select RabbitMQ version:" "3-management" "Other")"
        if [[ "${rabbitmq_version}" == "Other" ]]; then
          read -r -p "Enter RabbitMQ version (e.g. 3.9-management) [default: 3-management]: " rabbitmq_version
          rabbitmq_version="${rabbitmq_version:-3-management}"
        fi
      fi
      if [[ "${include_kafka}" == "true" ]]; then
        kafka_version="$(prompt_choice "Select Kafka version:" "latest" "Other")"
        if [[ "${kafka_version}" == "Other" ]]; then
          read -r -p "Enter Kafka version (e.g. 3.4) [default: latest]: " kafka_version
          kafka_version="${kafka_version:-latest}"
        fi
      fi
    fi
  fi

  env_dir="$(env_dir_for "${env_name}")"
  config_file="$(config_file_for "${env_name}")"
  devcontainer_dir="$(devcontainer_dir_for "${env_name}")"
  compose_file="$(compose_file_for "${env_name}")"
  mkdir -p "${env_dir}"

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

  render_config "${config_file}" "${env_name}" "${os_version}" "${include_go}" "${include_node}" "${include_python}" "${include_java}" "${include_php}" "${frontend_framework}" "${include_pg}" "${include_mysql}" "${include_mongodb}" "${include_redis}" "${include_rabbitmq}" "${include_kafka}" "${go_version}" "${node_version}" "${python_version}" "${java_version}" "${php_version}" "${pg_version}" "${mysql_version}" "${mongodb_version}" "${redis_version}" "${rabbitmq_version}" "${kafka_version}" "${pg_host_port}" "${mysql_host_port}" "${mongodb_host_port}" "${redis_host_port}" "${rabbitmq_host_port}" "${kafka_host_port}"
  render_devcontainer "${devcontainer_dir}" "${env_name}" "${os_version}" "${include_go}" "${include_node}" "${include_python}" "${include_java}" "${include_php}" "${frontend_framework}" "${go_version}" "${node_version}" "${python_version}" "${java_version}" "${php_version}"
  render_compose "${compose_file}" "${ROOT_DIR}" "${include_pg}" "${include_mysql}" "${include_mongodb}" "${include_redis}" "${include_rabbitmq}" "${include_kafka}" "${pg_version}" "${mysql_version}" "${mongodb_version}" "${redis_version}" "${rabbitmq_version}" "${kafka_version}" "${pg_host_port}" "${mysql_host_port}" "${mongodb_host_port}" "${redis_host_port}" "${rabbitmq_host_port}" "${kafka_host_port}"

  echo ""
  log_success "Generated environment: ${env_name}"
  echo "  - ${config_file}"
  echo "  - ${devcontainer_dir}/Dockerfile"
  echo "  - ${devcontainer_dir}/devcontainer.json"
  echo "  - ${compose_file}"
}
