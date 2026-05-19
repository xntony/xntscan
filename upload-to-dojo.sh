#!/bin/bash

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -e|--engagement)
      ENGAGEMENT_ID="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -o, --output-dir PATH   Path to the output directory with scan results"
      echo "  -e, --engagement ID     DefectDojo Engagement ID"
      echo "  -v, --verbose           Enable verbose output"
      echo "  -h, --help              Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set default values if not provided
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$HOME/audit-tools/output"
fi

if [ -z "$ENGAGEMENT_ID" ]; then
  ENGAGEMENT_ID="2"
fi

# Configuration settings
TOKEN="17ddbdc8fb16660afa4dda0ce48f94204718d3a4"
DOJO_URL="http://localhost:8080/api/v2/import-scan/"

# Array mapping local files to their native DefectDojo scan types
declare -A SCANS
SCANS["$OUTPUT_DIR/gitleaks.json"]="Gitleaks Scan"
SCANS["$OUTPUT_DIR/trivy-fs.json"]="Trivy Scan"
SCANS["$OUTPUT_DIR/trivy-config.json"]="Trivy Scan"
SCANS["$OUTPUT_DIR/trivy-image.json"]="Trivy Scan"
SCANS["$OUTPUT_DIR/auth-scan.json"]="Semgrep JSON Report"
SCANS["$OUTPUT_DIR/input-scan.json"]="Semgrep JSON Report"
SCANS["$OUTPUT_DIR/injection-scan.json"]="Semgrep JSON Report"
SCANS["$OUTPUT_DIR/additional-scan.json"]="Semgrep JSON Report"
SCANS["$OUTPUT_DIR/security-misconfig.json"]="Semgrep JSON Report"
SCANS["$OUTPUT_DIR/npm-audit.json"]="NPM Audit Scan"
SCANS["$OUTPUT_DIR/nodejsscan.json"]="NodeJsScan Scan"
SCANS["$OUTPUT_DIR/bearer.json"]="Bearer CLI"
SCANS["$OUTPUT_DIR/knip.json"]="Generic Findings Import"

echo "================================================="
echo "Starting Bulk Scan Upload to DefectDojo..."
echo "================================================="

# Track files that were skipped or not found
declare -A SKIPPED_FILES
TOTAL_FILES=0
UPLOADED_FILES=0

for FILE in "${!SCANS[@]}"; do
    SCAN_TYPE="${SCANS[$FILE]}"
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    # Check if file exists
    if [ ! -f "$FILE" ]; then
        if [ "$VERBOSE" = true ]; then
            echo "⚠️  Skipping $FILE: File not found."
        fi
        SKIPPED_FILES["$FILE"]="File not found"
        continue
    fi

    # Check if file is empty or null
    if [ ! -s "$FILE" ] || [ "$(cat "$FILE")" = "null" ]; then
        if [ "$VERBOSE" = true ]; then
            if [ ! -s "$FILE" ]; then
                echo "⏭  Skipping $FILE: Empty file."
                SKIPPED_FILES["$FILE"]="Empty file"
            else
                echo "⏭  Skipping $FILE: null content."
                SKIPPED_FILES["$FILE"]="null content"
            fi
        else
            SKIPPED_FILES["$FILE"]="Skipped"
        fi
        continue
    fi

    echo "🚀 Uploading $FILE as '$SCAN_TYPE'..."

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X 'POST' "$DOJO_URL" \
      -H "Authorization: Token $TOKEN" \
      -H "Content-Type: multipart/form-data" \
      -F "scan_type=$SCAN_TYPE" \
      -F "active=true" \
      -F "verified=false" \
      -F "minimum_severity=Info" \
      -F "engagement=$ENGAGEMENT_ID" \
      -F "file=@$FILE")

    if [ "$RESPONSE" == "201" ]; then
        echo "✅ Successfully imported $FILE"
        UPLOADED_FILES=$((UPLOADED_FILES + 1))
    else
        echo "❌ Failed to import $FILE (HTTP Status: $RESPONSE)"
    fi
    echo "-------------------------------------------------"
done

# Show verbose output if requested
if [ "$VERBOSE" = true ]; then
    echo ""
    echo "=== Upload Summary ==="
    echo "Total files processed: $TOTAL_FILES"
    echo "Successfully uploaded: $UPLOADED_FILES"
    echo "Files skipped: ${#SKIPPED_FILES[@]}"
    
    if [ ${#SKIPPED_FILES[@]} -gt 0 ]; then
        echo "Skipped files details:"
        for file in "${!SKIPPED_FILES[@]}"; do
            echo "  - $file (${SKIPPED_FILES[$file]})"
        done
    fi
fi

echo "================================================="
echo "Bulk upload complete! Check your DefectDojo dashboard."
echo "================================================="
