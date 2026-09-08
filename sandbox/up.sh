#!/usr/bin/env bash
# Starts the whole sandbox and tells you where to click.
#
#   ./sandbox/up.sh          start everything
#   ./sandbox/up.sh down     stop everything
#
# Five services. The mocked ledger runs as a container; the four applications run as
# processes, which is faster to iterate on and easier to debug than rebuilding images.
set -euo pipefail
cd "$(dirname "$0")/.."

PKI=${PKI_DIR:-/tmp/psd2-pki}
LOGS=${LOG_DIR:-/tmp/psd2-logs}
DOCKER=${DOCKER:-docker}
[ -x "$HOME/.rd/bin/docker" ] && DOCKER="$HOME/.rd/bin/docker"

# Match on the jar names this script starts, not on a directory name: the java command
# line is relative, so a pattern naming the repo would match nothing and leave the old
# process holding the port.
PATTERNS='bank-xs2a-.*\.jar|bank-ciam-.*\.jar|oidc-provider-.*\.jar|tpp-backend/dist/main\.js'

stop() {
  pkill -f "$PATTERNS" 2>/dev/null || true
  # Ports are released a moment after the process goes, and Boot's failure to bind is
  # fatal — so wait for them rather than racing.
  for _ in $(seq 1 20); do
    pgrep -f "$PATTERNS" >/dev/null 2>&1 || break
    sleep 0.5
  done
  pkill -9 -f "$PATTERNS" 2>/dev/null || true
  $DOCKER compose -f sandbox/compose.yaml down 2>/dev/null || true
  echo "sandbox stopped"
}
[ "${1:-up}" = "down" ] && { stop; exit 0; }

command -v java >/dev/null || { echo "java not on PATH — sdk use java 25.0.2-tem"; exit 1; }
command -v node >/dev/null || { echo "node not on PATH — nvm use --lts"; exit 1; }

stop >/dev/null 2>&1 || true
mkdir -p "$LOGS"; rm -rf "$PKI"

wait_for() {  # wait_for <log> <marker> <name>
  local waited=0
  until grep -q "$2" "$1" 2>/dev/null; do
    sleep 1; waited=$((waited + 1))
    [ $waited -gt 90 ] && { echo "  $3 did not start; see $1"; exit 1; }
  done
  echo "  $3"
}

echo "starting the sandbox…"
$DOCKER compose -f sandbox/compose.yaml up -d >/dev/null 2>&1 && echo "  bank-core (Microcks)"

# bank-xs2a first: it owns the CA the others read.
nohup java -jar bank/bank-xs2a/target/bank-xs2a-*.jar \
  --server.port=8443 --sandbox.pki.directory="$PKI" > "$LOGS/bank-xs2a.log" 2>&1 &
wait_for "$LOGS/bank-xs2a.log" 'Started BankXs2aApplication' 'bank-xs2a      :8443 (mTLS) :8081 (internal)'

nohup java -jar bank/bank-ciam/target/bank-ciam-*.jar \
  --server.port=9443 > "$LOGS/bank-ciam.log" 2>&1 &
nohup java -jar oidc-provider/target/oidc-provider-*.jar \
  --server.port=7443 --sandbox.pki.directory="$PKI" > "$LOGS/oidc-provider.log" 2>&1 &
wait_for "$LOGS/bank-ciam.log" 'Started CiamApplication' 'bank-ciam      :9443'
wait_for "$LOGS/oidc-provider.log" 'Started OidcProviderApplication' 'oidc-provider  :7443 (mTLS) :7080 (browser)'

PKI_DIR="$PKI" nohup node apps/tpp-backend/dist/main.js > "$LOGS/tpp.log" 2>&1 &
wait_for "$LOGS/tpp.log" 'TPP listening' 'tpp            :5173'

cat <<'EOF'

  Open the TPP:        http://localhost:5173
  Device simulator:    http://localhost:9443/simulator/index.html
  Microcks console:    http://localhost:8585

  The journey: sign in at the TPP, Connect the bank, sign in at the bank,
  choose accounts, then approve in the simulator (open it, Enrol, then paste
  the payload the bank's page shows). You land back on your accounts.

  Logs in /tmp/psd2-logs.  Stop with ./sandbox/up.sh down
EOF
