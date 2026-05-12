#!/usr/bin/env bash

render_config() {
  local target_config_file="$1"
  local env_name="$2"
  local os_version="$3"
  local include_go="$4"
  local include_node="$5"
  local include_python="$6"
  local include_java="$7"
  local include_php="$8"
  local frontend_framework="$9"
  local include_pg="${10}"
  local include_mysql="${11}"
  local include_mongodb="${12}"
  local include_redis="${13}"
  local include_rabbitmq="${14}"
  local include_kafka="${15}"
  local go_version="${16}"
  local node_version="${17}"
  local python_version="${18}"
  local java_version="${19}"
  local php_version="${20}"
  local pg_version="${21}"
  local mysql_version="${22}"
  local mongodb_version="${23}"
  local redis_version="${24}"
  local rabbitmq_version="${25}"
  local kafka_version="${26}"

  cat > "${target_config_file}" <<EOF
version: 1
name: ${env_name}
backend: devcontainer

os:
  distro: ubuntu
  version: "${os_version}"

languages:
  go: ${include_go}
  node: ${include_node}
  python: ${include_python}
  java: ${include_java}
  php: ${include_php}

versions:
  go: "${go_version}"
  node: "${node_version}"
  python: "${python_version}"
  java: "${java_version}"
  php: "${php_version}"

frontend:
  framework: ${frontend_framework}

features:
  system_tools: true
  git_ssh: true
  docker_compose: true
  make_lint: true
  project_init: true

services:
  postgres:
    enabled: ${include_pg}
    version: "${pg_version}"
    port: 5432
  mysql:
    enabled: ${include_mysql}
    version: "${mysql_version}"
    port: 3306
  mongodb:
    enabled: ${include_mongodb}
    version: "${mongodb_version}"
    port: 27017
  redis:
    enabled: ${include_redis}
    version: "${redis_version}"
    port: 6379
  rabbitmq:
    enabled: ${include_rabbitmq}
    version: "${rabbitmq_version}"
    port: 5672
  kafka:
    enabled: ${include_kafka}
    version: "${kafka_version}"
    port: 9092
EOF
}

render_devcontainer() {
  local target_devcontainer_dir="$1"
  local env_name="$2"
  local os_version="$3"
  local include_go="$4"
  local include_node="$5"
  local include_python="$6"
  local include_java="$7"
  local include_php="$8"
  local frontend_framework="$9"
  local go_version="${10}"
  local node_version="${11}"
  local python_version="${12}"
  local java_version="${13}"
  local php_version="${14}"
  mkdir -p "${target_devcontainer_dir}" "${GENERATED_DIR}"

  cat > "${target_devcontainer_dir}/Dockerfile" <<EOF
FROM ubuntu:${os_version}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \\
    ca-certificates curl wget jq unzip git openssh-client make build-essential \\
    gnupg lsb-release software-properties-common && \\
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
EOF

  if [[ "${include_go}" == "true" ]]; then
    cat >> "${target_devcontainer_dir}/Dockerfile" <<EOF

# Go
RUN curl -fsSL https://go.dev/dl/go${go_version}.linux-amd64.tar.gz -o /tmp/go.tar.gz && \\
    rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tar.gz && \\
    rm -f /tmp/go.tar.gz

ENV PATH="/usr/local/go/bin:\${PATH}"
EOF
  fi

  if [[ "${include_node}" == "true" ]]; then
    cat >> "${target_devcontainer_dir}/Dockerfile" <<EOF

# Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${node_version}.x | bash - && \\
    apt-get update && apt-get install -y --no-install-recommends nodejs && \\
    rm -rf /var/lib/apt/lists/*
EOF
  fi

  if [[ "${include_python}" == "true" ]]; then
    if [[ "${python_version}" == "system" ]]; then
      cat >> "${target_devcontainer_dir}/Dockerfile" <<'EOF'

# Python (System Default)
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip python3-venv && \
    rm -rf /var/lib/apt/lists/*
EOF
    else
      cat >> "${target_devcontainer_dir}/Dockerfile" <<EOF

# Python ${python_version}
RUN add-apt-repository ppa:deadsnakes/ppa -y && \\
    apt-get update && apt-get install -y --no-install-recommends python${python_version} python${python_version}-venv python3-pip && \\
    rm -rf /var/lib/apt/lists/*
EOF
    fi
  fi

  if [[ "${include_java}" == "true" ]]; then
    cat >> "${target_devcontainer_dir}/Dockerfile" <<EOF

# Java (OpenJDK ${java_version}) & Maven
RUN apt-get update && apt-get install -y --no-install-recommends openjdk-${java_version}-jdk maven && \\
    rm -rf /var/lib/apt/lists/*
EOF
  fi

  if [[ "${include_php}" == "true" ]]; then
    if [[ "${php_version}" == "system" ]]; then
      cat >> "${target_devcontainer_dir}/Dockerfile" <<'EOF'

# PHP & Composer (System Default)
RUN apt-get update && apt-get install -y --no-install-recommends php-cli php-curl php-xml php-mbstring && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    rm -rf /var/lib/apt/lists/*
EOF
    else
      cat >> "${target_devcontainer_dir}/Dockerfile" <<EOF

# PHP ${php_version} & Composer
RUN add-apt-repository ppa:ondrej/php -y && \\
    apt-get update && apt-get install -y --no-install-recommends php${php_version}-cli php${php_version}-curl php${php_version}-xml php${php_version}-mbstring && \\
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \\
    update-alternatives --set php /usr/bin/php${php_version} || true && \\
    rm -rf /var/lib/apt/lists/*
EOF
    fi
  fi

  local extensions='"ms-azuretools.vscode-docker"'
  if [[ "${include_go}" == "true" ]]; then extensions+=', "golang.go"'; fi
  if [[ "${include_node}" == "true" ]]; then extensions+=', "dbaeumer.vscode-eslint"'; fi
  if [[ "${include_python}" == "true" ]]; then extensions+=', "ms-python.python"'; fi
  if [[ "${include_java}" == "true" ]]; then extensions+=', "vscjava.vscode-java-pack"'; fi
  if [[ "${include_php}" == "true" ]]; then extensions+=', "bmewburn.vscode-intelephense-client"'; fi
  if [[ "${frontend_framework}" == "react" ]]; then extensions+=', "dsznajder.es7-react-js-snippets"'; fi
  if [[ "${frontend_framework}" == "vue" ]]; then extensions+=', "Vue.volar"'; fi

  cat > "${target_devcontainer_dir}/devcontainer.json" <<EOF
{
  "name": "${env_name}",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "workspace",
  "workspaceFolder": "/workspace",
  "customizations": {
    "vscode": {
      "extensions": [
        ${extensions}
      ]
    }
  }
}
EOF
}

render_compose() {
  local target_compose_file="$1"
  local default_project_path="$2"
  local include_pg="$3"
  local include_mysql="$4"
  local include_mongodb="$5"
  local include_redis="$6"
  local include_rabbitmq="$7"
  local include_kafka="$8"
  local pg_version="$9"
  local mysql_version="${10}"
  local mongodb_version="${11}"
  local redis_version="${12}"
  local rabbitmq_version="${13}"
  local kafka_version="${14}"

  cat > "${target_compose_file}" <<EOF
services:
  workspace:
    build:
      context: ./.devcontainer
      dockerfile: Dockerfile
    volumes:
      - \${PROJECT_PATH:-${default_project_path}}:/workspace
    command: sleep infinity
EOF

  if [[ "${include_pg}" == "true" ]]; then
    cat >> "${target_compose_file}" <<EOF
  postgres:
    image: postgres:${pg_version}
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: devdb
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
EOF
  fi

  if [[ "${include_mysql}" == "true" ]]; then
    cat >> "${target_compose_file}" <<EOF
  mysql:
    image: mysql:${mysql_version}
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: devdb
      MYSQL_USER: dev
      MYSQL_PASSWORD: dev
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
EOF
  fi

  if [[ "${include_mongodb}" == "true" ]]; then
    cat >> "${target_compose_file}" <<EOF
  mongodb:
    image: mongo:${mongodb_version}
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: root
      MONGO_INITDB_DATABASE: devdb
    ports:
      - "27017:27017"
    volumes:
      - mongodb-data:/data/db
EOF
  fi

  if [[ "${include_redis}" == "true" ]]; then
    cat >> "${target_compose_file}" <<EOF
  redis:
    image: redis:${redis_version}
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
EOF
  fi

  if [[ "${include_rabbitmq}" == "true" ]]; then
    cat >> "${target_compose_file}" <<EOF
  rabbitmq:
    image: rabbitmq:${rabbitmq_version}
    environment:
      RABBITMQ_DEFAULT_USER: dev
      RABBITMQ_DEFAULT_PASS: dev
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq-data:/var/lib/rabbitmq
EOF
  fi

  if [[ "${include_kafka}" == "true" ]]; then
    cat >> "${target_compose_file}" <<EOF
  kafka:
    image: bitnami/kafka:${kafka_version}
    environment:
      KAFKA_CFG_NODE_ID: 0
      KAFKA_CFG_PROCESS_ROLES: controller,broker
      KAFKA_CFG_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: 0@kafka:9093
      KAFKA_CFG_CONTROLLER_LISTENER_NAMES: CONTROLLER
    ports:
      - "9092:9092"
    volumes:
      - kafka-data:/bitnami/kafka
EOF
  fi

  if [[ "${include_pg}" == "true" || "${include_mysql}" == "true" || "${include_mongodb}" == "true" || "${include_redis}" == "true" || "${include_rabbitmq}" == "true" || "${include_kafka}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'

volumes:
EOF
  fi

  if [[ "${include_pg}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'
  postgres-data:
EOF
  fi

  if [[ "${include_mysql}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'
  mysql-data:
EOF
  fi

  if [[ "${include_mongodb}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'
  mongodb-data:
EOF
  fi

  if [[ "${include_redis}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'
  redis-data:
EOF
  fi

  if [[ "${include_rabbitmq}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'
  rabbitmq-data:
EOF
  fi

  if [[ "${include_kafka}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'
  kafka-data:
EOF
  fi
}
