#!/bin/bash

set -euo pipefail

# Default values
PROJECT_DIR=""
OUTPUT_DIR=""
IMAGE_NAME=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--path)
      PROJECT_DIR="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -p, --path PATH     Path to the project directory to scan"
      echo "  -o, --output PATH   Output directory for scan results"
      echo "  -h, --help          Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set default values if not provided
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR=$(pwd)
fi

if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$PROJECT_DIR/output"
fi

IMAGE_NAME="nodegoat-app:latest"
VENV_DIR="$PROJECT_DIR/.scan-venv"

mkdir -p "$OUTPUT_DIR"

RISK_SCORE=0

# ─── Python venv setup (for nodejsscan) ──────────────────────────────────────
echo "================================================"
echo "SETUP: Python venv for nodejsscan"
echo "================================================"
if ! python3 -m venv "$VENV_DIR"; then
  echo "⚠ Failed to create venv — nodejsscan will be skipped"
  VENV_OK=false
else
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
  pip install --quiet --upgrade pip
  pip install --quiet nodejsscan
  VENV_OK=true
fi

# Additional security checks for enhanced scanning
echo "================================================"
echo "ENHANCED: Additional security checks"
echo "================================================"
echo "Adding additional security checks for comprehensive scanning"
echo "→ Checking for path traversal vulnerabilities..."
if command -v checkov &>/dev/null; then
  echo "→ Running Checkov for infrastructure as code scanning..."
  checkov -d "$PROJECT_DIR" --output json --output-file-path "$OUTPUT_DIR/checkov-report.json" || true
  echo "✔ Checkov scan complete"
fi

echo "→ Running additional Semgrep rules for comprehensive scanning..."
# 4d: Path traversal checks
semgrep \
  --config "p/inventory" \
  --config "p/command-injection" \
  "$PROJECT_DIR" --json > "$OUTPUT_DIR/additional-scan.json" || true
echo "✔ Additional semgrep checks complete"

# 4e: Business logic and security misconfigurations
echo "→ [4e] Business logic and misconfig checks..."
semgrep \
  --config "p/insecure-transport" \
  --config "p/password-storage" \
  --config "p/command-injection" \
  --config "p/ci" \
  "$PROJECT_DIR" --json > "$OUTPUT_DIR/security-misconfig.json" || true
echo "✔ Business logic checks complete"


echo "================================================"
echo "1/9 GITLEAKS (Secrets)"
echo "================================================"
gitleaks detect --source "$PROJECT_DIR" \
  --report-format json \
  --report-path "$OUTPUT_DIR/gitleaks.json" || true


echo "================================================"
echo "2/9 TRIVY FS (Dependencies)"
echo "================================================"
trivy fs "$PROJECT_DIR" \
  --format json \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --output "$OUTPUT_DIR/trivy-fs.json" || RISK_SCORE=$((RISK_SCORE+25))


echo "================================================"
echo "3/9 TRIVY CONFIG (Misconfig)"
echo "================================================"
trivy config "$PROJECT_DIR" \
  --format json \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --output "$OUTPUT_DIR/trivy-config.json" || RISK_SCORE=$((RISK_SCORE+25))


echo "================================================"
echo "4/9 SEMGREP — Targeted SAST"
echo "================================================"

# 4a: Auth flows — JWT handling, hardcoded secrets, auth bypass patterns
echo "→ [4a] Auth flows (JWT + secrets)..."
semgrep \
  --config "p/jwt" \
  --config "p/secrets" \
  "$PROJECT_DIR" --json > "$OUTPUT_DIR/auth-scan.json" || RISK_SCORE=$((RISK_SCORE+25))
echo "✔ auth-scan.json"

# 4b: Input validation gaps — Node.js best practices + OWASP Top 10
echo "→ [4b] Input validation (nodejs + owasp-top-ten)..."
semgrep \
  --config "p/nodejs" \
  --config "p/owasp-top-ten" \
  "$PROJECT_DIR" --json > "$OUTPUT_DIR/input-scan.json" || RISK_SCORE=$((RISK_SCORE+25))
echo "✔ input-scan.json"

# 4c: SQL/NoSQL injection surface
echo "→ [4c] Injection surface (sql-injection)..."
semgrep \
  --config "p/sql-injection" \
  "$PROJECT_DIR" --json > "$OUTPUT_DIR/injection-scan.json" || RISK_SCORE=$((RISK_SCORE+25))
echo "✔ injection-scan.json"


echo "================================================"
echo "5/9 CONTAINER SCAN (Trivy Image)"
echo "================================================"
if [ -f "$PROJECT_DIR/Dockerfile" ]; then
  echo "Dockerfile found → building image..."
  if docker build -t "$IMAGE_NAME" "$PROJECT_DIR" 2>/dev/null; then
    echo "Build successful → scanning image"
    trivy image "$IMAGE_NAME" \
      --format json \
      --severity HIGH,CRITICAL \
      --exit-code 1 \
      --output "$OUTPUT_DIR/trivy-image.json" || RISK_SCORE=$((RISK_SCORE+25))
  else
    echo "Docker build failed → skipping scan"
    RISK_SCORE=$((RISK_SCORE+50))
  fi
else
  echo "No Dockerfile found → skipping container scan"
  echo "null" > "$OUTPUT_DIR/trivy-image.json"
fi


echo "================================================"
echo "6/9 NPM AUDIT (Known Vulnerabilities)"
echo "================================================"
if [ -f "$PROJECT_DIR/package.json" ]; then
  npm audit --json --prefix "$PROJECT_DIR" > "$OUTPUT_DIR/npm-audit.json" 2>&1 || true

  HIGH_COUNT=$(jq '[.vulnerabilities // {} | to_entries[].value
    | select(.severity == "high" or .severity == "critical")] | length' \
    "$OUTPUT_DIR/npm-audit.json" 2>/dev/null || echo 0)

  if [ "$HIGH_COUNT" -gt 0 ]; then
    echo "⚠ npm audit: $HIGH_COUNT high/critical vulnerability/ies found"
    RISK_SCORE=$((RISK_SCORE+25))
  else
    echo "✔ npm audit: no high/critical vulnerabilities"
  fi
else
  echo "No package.json found → skipping npm audit"
  echo "null" > "$OUTPUT_DIR/npm-audit.json"
fi


echo "================================================"
echo "7/9 KNIP (Dead Code / Unused Exports)"
echo "================================================"
if [ -f "$PROJECT_DIR/package.json" ]; then
  npx --yes knip --reporter json --cwd "$PROJECT_DIR" > "$OUTPUT_DIR/knip.json" 2>&1 || true
  echo "✔ knip scan complete (see output/knip.json)"
else
  echo "No package.json found → skipping knip"
  echo "null" > "$OUTPUT_DIR/knip.json"
fi


echo "================================================"
echo "8/9 NODEJSSCAN (Python SAST — venv)"
echo "================================================"
if [ "$VENV_OK" = true ]; then
  nodejsscan -d "$PROJECT_DIR" -o "$OUTPUT_DIR/nodejsscan.json" || RISK_SCORE=$((RISK_SCORE+25))
  echo "✔ nodejsscan complete"
  deactivate
else
  echo "⚠ Skipped — venv not available"
  echo "null" > "$OUTPUT_DIR/nodejsscan.json"
fi


echo "================================================"
echo "9/9 BEARER (Privacy / OWASP SAST)"
echo "================================================"
if command -v bearer &>/dev/null; then
  bearer scan "$PROJECT_DIR" \
    --format json \
    --output "$OUTPUT_DIR/bearer.json" \
    --severity critical,high \
    --exit-code 1 || RISK_SCORE=$((RISK_SCORE+25))
  echo "✔ bearer scan complete"
else
  echo "⚠ bearer not found — installing via curl..."
  curl -sfL https://raw.githubusercontent.com/Bearer/bearer/main/contrib/install.sh | sh -s -- -b /usr/local/bin
  bearer scan "$PROJECT_DIR" \
    --format json \
    --output "$OUTPUT_DIR/bearer.json" \
    --severity critical,high \
    --exit-code 1 || RISK_SCORE=$((RISK_SCORE+25))
  echo "✔ bearer scan complete"
fi


echo "================================================"
echo "BONUS: ENTRY POINTS (Routes/Controllers)"
echo "================================================"
find "$PROJECT_DIR" -name "*.ts" -o -name "*.js" | xargs grep -rn \
  "router\.\|app\.get\|app\.post\|app\.put\|app\.delete\|@Controller\|@Get\|@Post" \
  --include="*.ts" --include="*.js" \
  > "$OUTPUT_DIR/entry-points.txt" || true
echo "✔ Entry points mapped → output/entry-points.txt"

echo "================================================"
echo "BONUS: ENV VARIABLES (Config surface)"
echo "================================================"
find "$PROJECT_DIR" -name "*.ts" -o -name "*.js" | xargs grep -rn "process\.env\." \
  --include="*.ts" --include="*.js" \
  > "$OUTPUT_DIR/env-usage.txt" || true
echo "✔ Env variable usage → output/env-usage.txt"


echo "================================================"
echo "Generating unified report..."
echo "================================================"

# Merge the three semgrep targeted scans into one results array
jq -s '
  { results: (map(.results // []) | add),
    errors:  (map(.errors  // []) | add),
    paths:   { scanned: (map(.paths.scanned // []) | add) }
  }
' \
  "$OUTPUT_DIR/auth-scan.json" \
  "$OUTPUT_DIR/input-scan.json" \
  "$OUTPUT_DIR/injection-scan.json" \
  > "$OUTPUT_DIR/semgrep-merged.json"

jq -n \
  --slurpfile gitleaks       "$OUTPUT_DIR/gitleaks.json" \
  --slurpfile trivy_fs       "$OUTPUT_DIR/trivy-fs.json" \
  --slurpfile trivy_cfg      "$OUTPUT_DIR/trivy-config.json" \
  --slurpfile auth_scan      "$OUTPUT_DIR/auth-scan.json" \
  --slurpfile input_scan     "$OUTPUT_DIR/input-scan.json" \
  --slurpfile injection_scan "$OUTPUT_DIR/injection-scan.json" \
  --slurpfile semgrep_merged "$OUTPUT_DIR/semgrep-merged.json" \
  --slurpfile trivy_img      "$OUTPUT_DIR/trivy-image.json" \
  --slurpfile npm_audit      "$OUTPUT_DIR/npm-audit.json" \
  --slurpfile knip           "$OUTPUT_DIR/knip.json" \
  --slurpfile nodejsscan     "$OUTPUT_DIR/nodejsscan.json" \
  --slurpfile bearer         "$OUTPUT_DIR/bearer.json" \
  --arg score "$RISK_SCORE" \
  '{
    timestamp:      now,
    risk_score:     ($score | tonumber),
    gitleaks:       $gitleaks[0],
    trivy_fs:       $trivy_fs[0],
    trivy_config:   $trivy_cfg[0],
    semgrep: {
      auth:      $auth_scan[0],
      input:     $input_scan[0],
      injection: $injection_scan[0],
      merged:    $semgrep_merged[0]
    },
    trivy_image:    $trivy_img[0],
    npm_audit:      $npm_audit[0],
    knip:           $knip[0],
    nodejsscan:     $nodejsscan[0],
    bearer:         $bearer[0]
  }' > "$OUTPUT_DIR/unified-report.json"


echo "================================================"
echo "DONE ✔"
echo "RISK SCORE: $RISK_SCORE / 100"
echo "Output files:"
echo "  output/auth-scan.json       ← JWT/secrets"
echo "  output/input-scan.json      ← Input validation"
echo "  output/injection-scan.json  ← SQL/NoSQL injection"
echo "  output/entry-points.txt     ← Route/controller map"
echo "  output/env-usage.txt        ← process.env surface"
echo "  output/unified-report.json  ← Full merged report"
echo "================================================"

if [ "$RISK_SCORE" -ge 50 ]; then
  echo "❌ Security threshold breached"
  exit 1
fi
