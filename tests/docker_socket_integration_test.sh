#!/usr/bin/env bash
set -euo pipefail

# Exercise the public create command in a disposable repository so generated
# artifacts and fake infrastructure never touch a developer's environments.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "${fixture}"' EXIT
cp -R "${ROOT_DIR}/scripts" "${fixture}/scripts"
mkdir -p "${fixture}/home/.ssh" "${fixture}/bin"
printf '%s\n' 'ssh-ed25519 AAAATEST fixture' > "${fixture}/home/.ssh/id_ed25519.pub"
cat > "${fixture}/bin/multipass" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == info ]]; then
  printf '{"info":{"%s":{"ipv4":["192.0.2.10"],"state":"Running"}}}\n' "$2"
fi
MOCK
chmod +x "${fixture}/bin/multipass"

fail() { echo "FAIL: $*" >&2; exit 1; }
contains() { grep -Eq -- "$2" "$1" || fail "$1 missing $2"; }
absent() { if grep -Eq -- "$2" "$1"; then fail "$1 unexpectedly contains $2"; fi; }
create() {
  env -u ENV -u OS -u LANGS -u FRONTEND -u DB -u BROKER \
    HOME="${fixture}/home" PATH="${fixture}/bin:${PATH}" \
    bash "${fixture}/scripts/chien-dev" create "$@" > "${fixture}/output" 2>&1
}
artifact() { printf '%s/generated/envs/%s/%s' "${fixture}" "$1" "$2"; }
assert_enabled() {
  local name="$1"
  contains "$(artifact "$name" docker-compose.yml)" '/var/run/docker.sock'
  contains "$(artifact "$name" .devcontainer/Dockerfile)" 'docker-ce-cli'
  contains "$(artifact "$name" .devcontainer/Dockerfile)" 'docker-compose-plugin'
  absent "$(artifact "$name" .devcontainer/Dockerfile)" 'apt-get install.*docker-ce( |$)|dockerd'
  contains "$(artifact "$name" chien-dev.yaml)" 'docker_socket'
}

create enabled --docker-socket || { cat "${fixture}/output" >&2; fail 'explicit socket enable rejected'; }
assert_enabled enabled
echo 'PASS: explicit socket option generates host socket access and Docker client tools'

reject() {
  local name="$1"
  shift
  if create "$name" "$@"; then fail "invalid request accepted: $*"; fi
  absent "${fixture}/output" 'Unknown flag'
  [[ ! -d "$(artifact "$name" '')" ]] || fail "invalid request created environment $name"
}
reject relative --docker-socket-path relative/docker.sock
reject missing --docker-socket-path
reject empty --docker-socket-path=
reject conflicting --docker-socket --no-docker-socket
reject conflictingreverse --no-docker-socket --docker-socket
reject pathdisabled --docker-socket-path /tmp/socket --no-docker-socket
reject disabledpath --no-docker-socket --docker-socket-path /tmp/socket
reject vmoption --backend vm --docker-socket
echo 'PASS: malformed paths and incompatible socket options fail before creating environments'

assert_disabled() {
  local name="$1"
  absent "$(artifact "$name" docker-compose.yml)" '/var/run/docker.sock'
  absent "$(artifact "$name" .devcontainer/Dockerfile)" 'docker-ce-cli|docker-compose-plugin|dockerd'
}
create default --backend devcontainer
assert_disabled default
create disabled --no-docker-socket
assert_disabled disabled
create custom --docker-socket-path /run/user/1000/docker.sock
assert_enabled custom
contains "$(artifact custom docker-compose.yml)" '/run/user/1000/docker.sock'
contains "$(artifact custom docker-compose.yml)" 'create_host_path: false'
contains "$(artifact custom chien-dev.yaml)" '/run/user/1000/docker.sock'
echo 'PASS: noninteractive defaults preserve isolation and custom paths enable socket access'

# Existing menu choices: DevContainer, Ubuntu 22.04, Go, no frontend,
# no database, no broker, then accept the new socket default.
printf '1\n1\n1\n1\n4\n4\n\n' | create interactive
assert_enabled interactive
contains "${fixture}/output" '[Hh]ost.*Docker|Docker.*[Hh]ost'
printf '1\n1\n1\n1\n4\n4\nn\n' | create declined
assert_disabled declined
echo 'PASS: interactive creation explains host access, defaults to yes and respects refusal'

if printf '1\n1\n1\n1\n4\n4\n' | create unconfirmed; then
  fail 'socket prompt EOF accepted as consent'
fi
[[ ! -d "$(artifact unconfirmed '')" ]] || fail 'socket prompt EOF generated environment'
echo 'PASS: unavailable socket answer does not count as consent'

create vm --backend vm
contains "$(artifact vm cloud-init.yaml)" '#cloud-config'
absent "$(artifact vm cloud-init.yaml)" 'docker.sock|docker-ce-cli|docker-compose-plugin|docker.io'
absent "$(artifact vm chien-dev.yaml)" 'docker_socket'
[[ ! -e "$(artifact vm docker-compose.yml)" ]] || fail 'VM unexpectedly generated Compose'
echo 'PASS: existing VM generation retains its independent backend'

# Literal expectations catch shell-version-specific replacement escaping and
# Compose interpolation independently of the renderer's implementation.
create quoted --docker-socket-path "/tmp/sock' \$CHIEN_UNSET: spaced.sock"
grep -Fq "path: '/tmp/sock'' \$CHIEN_UNSET: spaced.sock'" "$(artifact quoted chien-dev.yaml)" || fail 'custom socket config does not preserve YAML quote characters'
grep -Fq "source: '/tmp/sock'' \$\$CHIEN_UNSET: spaced.sock'" "$(artifact quoted docker-compose.yml)" || fail 'custom socket mount does not preserve YAML quotes and Compose dollars'
echo 'PASS: custom socket paths preserve apostrophes, spaces, colon and literal dollar characters'
