#!/usr/bin/env bash
set -euo pipefail

# Public seam: the real CLI in a disposable checkout. Only Multipass is fake.
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/chien-stale-vm.XXXXXX")"
trap 'rm -rf -- "${fixture}"' EXIT
cp -R "${SOURCE_DIR}/scripts" "${fixture}/scripts"
mkdir -p "${fixture}/bin"
cat > "${fixture}/bin/multipass" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  list)
    count=$(cat "${VM_FIXTURE}/count")
    count=$((count + 1))
    echo "$count" > "${VM_FIXTURE}/count"
    [[ ! -f "${VM_FIXTURE}/fail-${count}" ]] || exit 1
    reply="${VM_FIXTURE}/reply-${count}"
    [[ -f "$reply" ]] || reply="${VM_FIXTURE}/reply"
    cat "$reply"
    ;;
  delete|purge)
    printf '%s\n' "$*" >> "${VM_FIXTURE}/operations"
    [[ ! -f "${VM_FIXTURE}/delete-failure" ]]
    ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "${fixture}/bin/multipass"
fail() { echo "FAIL: $*" >&2; cat "${fixture}/output" >&2; exit 1; }
prepare() {
  name=demo
  mkdir -p "${fixture}/generated/envs/${name}" "${fixture}/generated/envs/unrelated"
  printf 'backend: vm\n' > "${fixture}/generated/envs/${name}/chien-dev.yaml"
  printf 'preserve unrelated assets\n' > "${fixture}/generated/envs/unrelated/sentinel"
  echo 0 > "${fixture}/count"
  : > "${fixture}/operations"
  rm -f "${fixture}"/reply-* "${fixture}"/fail-* "${fixture}/delete-failure"
  printf '{"list":[]}\n' > "${fixture}/reply"
}
cli() { VM_FIXTURE="${fixture}" PATH="${fixture}/bin:${PATH}" bash "${fixture}/scripts/chien-dev" "$@" > "${fixture}/output" 2>&1; }
present() { [[ -d "${fixture}/generated/envs/${name}" ]] || fail 'generated files unexpectedly removed'; }
removed() {
  [[ ! -d "${fixture}/generated/envs/${name}" ]] || fail 'stale generated files retained'
  [[ "$(cat "${fixture}/generated/envs/unrelated/sentinel")" == 'preserve unrelated assets' ]] || fail 'unrelated files changed'
}
no_delete() { [[ ! -s "${fixture}/operations" ]] || fail 'unexpected Multipass deletion'; }
inventory() { printf '{"list":[{"name":"demo","state":"%s","ipv4":[]}]}\n' "$1"; }

prepare
printf 'y\n' | cli clean "$name" || fail 'missing VM cleanup rejected'
removed; no_delete
echo 'PASS: confirmed missing VM removes only stale generated files'

prepare
cli status "$name" || fail 'status could not report confirmed absence'
grep -Fq 'State: Missing' "${fixture}/output" || fail 'confirmed absence not labeled Missing'
grep -Fq "chien-dev clean ${name}" "${fixture}/output" || fail 'Missing status lacks cleanup hint'
present; no_delete

touch "${fixture}/fail-1"
echo 0 > "${fixture}/count"
cli status "$name" || fail 'status could not report unavailable inventory'
grep -Fq 'State: Unknown' "${fixture}/output" || fail 'unavailable inventory mislabeled as Missing'
present; no_delete
echo 'PASS: status is read-only and distinguishes confirmed absence from query failure'

prepare
printf '{"list":[{"name":"demo","state":"Stopped","ipv4":[]},{"name":"unrelated","state":"Deleted","ipv4":[]}]}\n' > "${fixture}/reply"
printf 'y\n' | cli clean "$name" || fail 'stopped VM cleanup failed'
[[ "$(cat "${fixture}/operations")" == 'delete --purge demo' ]] || fail 'permanent deletion was not limited to the exact VM'
removed

prepare
inventory Deleted > "${fixture}/reply"
printf 'y\n' | cli clean "$name" || fail 'Deleted VM cleanup failed'
[[ "$(cat "${fixture}/operations")" == 'delete --purge demo' ]] || fail 'Deleted VM purge was not scoped'
removed
echo 'PASS: Stopped and Deleted cleanup purges only the selected VM'

prepare
printf '{"list":[{"name":"elsewhere","state":"Running"},{"name":"unrelated","state":"Deleted"}]}\n' > "${fixture}/reply"
printf 'y\n' | cli clean "$name" || fail 'unrelated instances prevented confirmed missing cleanup'
removed; no_delete

# A command must produce exactly one reliable inventory, not a stream where an
# empty list could conceal a later same-name running instance.
prepare
printf '{"list":[]}\n{"list":[{"name":"demo","state":"Running"}]}\n' > "${fixture}/reply"
if printf 'y\n' | cli clean "$name"; then fail 'multiple inventory JSON documents authorized cleanup'; fi
present; no_delete
cli status "$name" || fail 'status could not report invalid response'
grep -Fq 'State: Unknown' "${fixture}/output" || fail 'multiple JSON documents did not produce Unknown'
echo 'PASS: exact-name absence is respected and multiple JSON documents are unsafe'

for response in \
  '{"list":null}' \
  '{"errors":["daemon unavailable"],"list":[]}' \
  '{"errors":false,"list":[]}' \
  '{"list":[{"name":"demo","state":"Stopped","ipv4":false}]}' \
  '{"list":[{"name":"demo","state":"Stopped"},{"name":"demo","state":"Running"}]}' \
  '{"list":[{"name":"demo","state":"Stopped","ipv4":"invalid"}]}' \
  '{"list":[{"name":"demo","state":""}]}' \
  'not-json'; do
  prepare
  printf '%s\n' "$response" > "${fixture}/reply"
  if printf 'y\n' | cli clean "$name"; then fail 'invalid inventory authorized cleanup'; fi
  present; no_delete
  cli status "$name" || fail 'status failed to report malformed inventory'
  grep -Fq 'State: Unknown' "${fixture}/output" || fail 'malformed inventory mislabeled Missing'
done
prepare
touch "${fixture}/fail-1"
if printf 'y\n' | cli clean "$name"; then fail 'Multipass failure authorized cleanup'; fi
present; no_delete
echo 'PASS: unavailable, malformed, error and duplicate inventories preserve files'

for answer in n ''; do
  prepare
  printf '%s\n' "$answer" | cli clean "$name" || fail 'declined/default-no cleanup failed'
  present; no_delete
done
prepare
cli clean "$name" < /dev/null || fail 'EOF cancellation failed'
present; no_delete

for state in Running Unknown Starting; do
  prepare
  inventory "$state" > "${fixture}/reply"
  if cli clean "$name" < /dev/null; then fail "unsafe $state VM was not refused"; fi
  present; no_delete
done
echo 'PASS: no consent and unsafe VM states never remove resources'

for state in Stopped Running Deleted; do
  prepare
  inventory "$state" > "${fixture}/reply-2"
  if printf 'y\n' | cli clean "$name"; then fail "same-name $state VM appeared during consent but cleanup succeeded"; fi
  present; no_delete
done
prepare
inventory Stopped > "${fixture}/reply-1"
inventory Running > "${fixture}/reply-2"
if printf 'y\n' | cli clean "$name"; then fail 'VM started during consent but cleanup succeeded'; fi
present; no_delete
prepare
touch "${fixture}/fail-2"
if printf 'y\n' | cli clean "$name"; then fail 'post-consent query failure authorized cleanup'; fi
present; no_delete
prepare
printf '{"list":null}\n' > "${fixture}/reply-2"
if printf 'y\n' | cli clean "$name"; then fail 'post-consent malformed inventory authorized cleanup'; fi
present; no_delete
echo 'PASS: post-confirmation reappearance, running and unreliable state refuse cleanup'

prepare
inventory Stopped > "${fixture}/reply-1"
printf 'y\n' | cli clean "$name" || fail 'VM removed externally during consent left stale assets'
removed; no_delete

prepare
inventory Stopped > "${fixture}/reply"
touch "${fixture}/delete-failure"
if printf 'y\n' | cli clean "$name"; then fail 'failed VM deletion reported success'; fi
present
[[ "$(cat "${fixture}/operations")" == 'delete --purge demo' ]] || fail 'failed deletion affected unselected VMs'
echo 'PASS: external removal permits file-only cleanup; delete failure preserves generated files'

prepare
printf 'backend: unexpected\n' > "${fixture}/generated/envs/${name}/chien-dev.yaml"
if printf 'y\n' | cli clean "$name"; then fail 'unknown backend authorized cleanup'; fi
present; no_delete

prepare
cli status "$name" || fail 'Missing status failed'
present; no_delete
printf 'y\n' | cli clean "$name" || fail 'stale registration cleanup failed'
removed; no_delete
cli status "$name" || fail 'status failed after cleanup'
grep -Fq 'not found' "${fixture}/output" || fail 'status retained cleaned registration'
echo 'PASS: unknown backend is protected and cleaned registration disappears from status'

prepare
rm -- "${fixture}/generated/envs/${name}/chien-dev.yaml"
printf 'incomplete environment assets\n' > "${fixture}/generated/envs/${name}/sentinel"
if printf 'y\n' | cli clean "$name"; then fail 'unresolved backend allowed incomplete assets cleanup'; fi
present; no_delete
[[ "$(cat "${fixture}/generated/envs/${name}/sentinel")" == 'incomplete environment assets' ]] || fail 'unresolved backend changed incomplete assets'

prepare
rm -rf -- "${fixture}/generated/envs/${name}"
cli clean "$name" < /dev/null || fail 'no directory and no VM must remain a not-found no-op'
grep -Fq 'not found' "${fixture}/output" || fail 'absent environment lost its not-found report'
removed; no_delete
echo 'PASS: unresolved backend preserves incomplete assets while an absent environment is a no-op'
