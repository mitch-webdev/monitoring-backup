#!/bin/bash

# Script to monitor disk usage and send alerts by email (via Resend API)

# Basic Settings
HOSTNAME="" # Will be displayed in subject and body
FROM="Alerts <>" # Display name and from address
TO="" # To address
API_KEY="" # Add Resend API Key

BASE_DIR="/var/log/resources_monitoring"
ALERT_FILE="$BASE_DIR/alerts.log"
ALERT_STATUS_DIR="$BASE_DIR/status"

DISK_THRESHOLD=75

# Setup
mkdir -p "$BASE_DIR"
mkdir -p "$ALERT_STATUS_DIR"

# Get current usage

ROOT_PART_USAGE=$(df -h / | awk 'NR==2 {gsub("%",""); print $5}')

# Functions

log_skipped_alert() {

	local type=$1
	echo "[$(date)] Skipped alert for $type: already sent." >> "$ALERT_FILE"
}

send_alert() {

    local type="$1"
    local usage="$2"
    local status_file="${ALERT_STATUS_DIR}/${type}.status"

    # Skip if alert already sent
    if [ -f "$status_file" ]; then
        log_skipped_alert "$type"
        return
    fi

    touch "$status_file"

    local timestamp
    timestamp="$(date)"

    # -------- TEXT MESSAGE (LOG) --------
    local message
    message="[$timestamp] ALERT on $HOSTNAME: $type usage is at ${usage}%.
    Please clean up unnecessary files or increase disk size."

    echo "$message" >> "$ALERT_FILE"

    # -------- OPTIONAL DF OUTPUT --------
    local df_output=""
    if [ "$type" = "root_partition" ]; then
        df_output="$(df -h /)"

        {
            echo "root partition space used:"
            echo "$df_output"
            echo "--------------------------------"
        } >> "$ALERT_FILE"
    fi

    # -------- HTML MESSAGE --------

    # Convert message newlines to <br>
    local html_message
    html_message=$(echo "$message" | sed ':a;N;$!ba;s/\n/<br>/g')

    # Add df output nicely formatted
    if [ -n "$df_output" ]; then
        html_message+="
        <br><br>
        <strong>Root partition usage:</strong><br>
        <pre style=\"background:#f4f4f4;padding:10px;border-radius:5px;\">
${df_output}
        </pre>"
    fi

    # Wrap in proper HTML layout
    local html_body
    html_body="
    <html>
    <body style=\"font-family:Arial, sans-serif;\">
        <h2 style=\"color:#d9534f;\">⚠️ Disk Usage Alert</h2>

        <p>$html_message</p>

        <hr>
        <p style=\"font-size:12px;color:gray;\">
            Host: $HOSTNAME<br>
            Time: $timestamp
        </p>
    </body>
    </html>
    "

    # -------- SEND EMAIL --------
    local response
    response=$(curl -s -X POST "https://api.resend.com/emails/batch" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d @- <<EOF
[
  {
    "from": "$FROM",
    "to": ["$TO"],
    "subject": "⚠️ $HOSTNAME: High $type usage (${usage}%)",
    "html": $(jq -Rs . <<< "$html_body")
  }
]
EOF
)

    echo "[$(date)] Resend API Response: $response" >> "$ALERT_FILE"
}

# -------- TRIGGERS --------

if [ "$ROOT_PART_USAGE" -gt "$DISK_THRESHOLD" ]; then
    send_alert "root_partition" "$ROOT_PART_USAGE"
fi

# Clear alert state if back to normal
if [ "$ROOT_PART_USAGE" -le "$DISK_THRESHOLD" ]; then
    rm -f "$ALERT_STATUS_DIR/root_partition.status"
fi
