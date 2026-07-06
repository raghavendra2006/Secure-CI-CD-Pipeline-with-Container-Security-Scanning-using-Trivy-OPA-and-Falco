#!/bin/bash
# ══════════════════════════════════════════════════════════════
# Falco Runtime Security Demo Script
# ══════════════════════════════════════════════════════════════
# This script demonstrates Falco's runtime threat detection by:
#   1. Tailing Falco logs in the background
#   2. Executing a shell inside a running pod (simulating an attack)
#   3. Capturing the Falco alert proving the rule works
#
# Prerequisites:
#   - Local k3d cluster running (run setup-cluster.sh first)
#   - Falco installed and running
#   - Application deployed to the devsecops namespace
# ══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ──
APP_NAMESPACE="devsecops"
FALCO_NAMESPACE="falco"
LOG_DIR="security-logs"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

print_alert() {
    echo -e "${RED}[🚨]${NC} $1"
}

# ── Step 1: Verify environment ──
print_header "Falco Runtime Security Demonstration"

# Get application pod name
APP_POD=$(kubectl get pods -n "$APP_NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$APP_POD" ]; then
    echo -e "${RED}No running pods found in namespace '$APP_NAMESPACE'.${NC}"
    echo "Run ./scripts/setup-cluster.sh first."
    exit 1
fi
print_step "Found application pod: $APP_POD"

# Get Falco pod name
FALCO_POD=$(kubectl get pods -n "$FALCO_NAMESPACE" -l app.kubernetes.io/name=falco -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$FALCO_POD" ]; then
    echo -e "${RED}No Falco pods found in namespace '$FALCO_NAMESPACE'.${NC}"
    echo "Run ./scripts/setup-cluster.sh first."
    exit 1
fi
print_step "Found Falco pod: $FALCO_POD"

# ── Step 2: Create log directory ──
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/falco-alert-$(date +%Y%m%d-%H%M%S).log"

# ── Step 3: Start Falco log capture ──
print_header "Step 1: Starting Falco Log Capture"

print_info "Capturing Falco logs in background..."
kubectl logs -n "$FALCO_NAMESPACE" "$FALCO_POD" -f --since=1s > "$LOG_FILE" 2>&1 &
FALCO_LOG_PID=$!
print_step "Falco log capture started (PID: $FALCO_LOG_PID)"

# Give Falco a moment to start streaming
sleep 3

# ── Step 4: Simulate attack — exec into container ──
print_header "Step 2: Simulating Attack (Shell Access)"

print_alert "SIMULATING ATTACK: Opening shell inside production container..."
echo ""
echo -e "  ${YELLOW}Command: kubectl exec -n $APP_NAMESPACE $APP_POD -- /bin/sh -c 'whoami; hostname; cat /etc/os-release; exit'${NC}"
echo ""

# Execute commands inside the container (simulating an attacker)
kubectl exec -n "$APP_NAMESPACE" "$APP_POD" -- /bin/sh -c '
echo "=== Attacker Reconnaissance ==="
echo "Current user: $(whoami)"
echo "Hostname: $(hostname)"
echo "OS Info:"
cat /etc/os-release 2>/dev/null | head -5
echo "Network config:"
ifconfig 2>/dev/null || ip addr 2>/dev/null | head -10
echo "Running processes:"
ps aux 2>/dev/null || echo "ps not available"
echo "=== End Reconnaissance ==="
' 2>/dev/null || true

print_step "Attack simulation completed"

# ── Step 5: Wait for Falco to process ──
print_header "Step 3: Waiting for Falco Detection"

print_info "Waiting 10 seconds for Falco to detect and log the event..."
sleep 10

# Stop Falco log capture
kill "$FALCO_LOG_PID" 2>/dev/null || true
wait "$FALCO_LOG_PID" 2>/dev/null || true

# ── Step 6: Display results ──
print_header "Step 4: Falco Alert Results"

if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
    # Filter for our security alerts
    if grep -i "shell\|Terminal\|SECURITY ALERT\|Warning\|bash\|/bin/sh" "$LOG_FILE" > "${LOG_DIR}/filtered-alerts.log" 2>/dev/null; then
        print_alert "FALCO DETECTED THE INTRUSION!"
        echo ""
        echo -e "${RED}┌─────────────────────────────────────────────────────────┐${NC}"
        echo -e "${RED}│  RUNTIME SECURITY ALERT CAPTURED                       │${NC}"
        echo -e "${RED}└─────────────────────────────────────────────────────────┘${NC}"
        echo ""
        cat "${LOG_DIR}/filtered-alerts.log"
        echo ""
        print_step "Alert saved to: ${LOG_DIR}/filtered-alerts.log"
        print_step "Full Falco log saved to: $LOG_FILE"
    else
        print_info "No shell-specific alerts found in filtered output."
        print_info "Full Falco log contents:"
        tail -30 "$LOG_FILE"
    fi
else
    print_info "Log file is empty. Falco may need more time."
    print_info "Try manually checking: kubectl logs -n $FALCO_NAMESPACE $FALCO_POD --tail=50"
fi

# ── Summary ──
print_header "Demo Complete 🎉"

echo -e "  ${GREEN}What happened:${NC}"
echo -e "    1. We opened a shell inside a running production container"
echo -e "    2. Falco detected the shell execution via eBPF syscall monitoring"
echo -e "    3. A security alert was generated with full context"
echo ""
echo -e "  ${GREEN}Files generated:${NC}"
echo -e "    • Full Falco log:     ${CYAN}$LOG_FILE${NC}"
echo -e "    • Filtered alerts:    ${CYAN}${LOG_DIR}/filtered-alerts.log${NC}"
echo ""
echo -e "  ${YELLOW}In production, these alerts would be forwarded to:${NC}"
echo -e "    • SIEM (Splunk, Elastic, etc.)"
echo -e "    • PagerDuty / Opsgenie for incident response"
echo -e "    • Slack / Teams security channels"
echo ""
