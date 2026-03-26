#!/bin/bash

set -euo pipefail

# Config

DATE=$(date +"%Y%m%d_%H%M%S")
LOG_FILE=/var/log/site-backups.log # Choose log file path
MYSQLDUMP=/usr/bin/mysqldump
DAY_OF_WEEK=$(date +%u)
DAY_OF_MONTH=$(date +%d)
HOSTNAME="Enter desired hostname here or do substitue with hostname command"

# Email alert config
API_KEY="Enter Resend API key here" # To edit
FROM="Alert <alert@domain.com>" # To edit
TO="email@domain.com" # To edit
ALERT_FILE="/var/log/backup_alerts.log" # To edit
SERVER_IP="Add your server IP here" # To edit

# Backup retention period
DAILY_RETENTION=30
WEEKLY_RETENTION=100
MONTHLY_RETENTION=365

# Sites config
# Format: "site_name:type:webroot:database_name:db_user:container_name"
# Example 1 is a simple website with DB
# Example 2 is a site that runs on docker and uses postgresql from docker as well
SITES=(
	"site1:mysql:/var/www/site1:db1" # Example 1
	"site2:docker-postgres:/var/www/site2:postgres_db:postgres_user:postgres_container" # Example 2
)

# Logging
log() {
	local MESSAGE="$1"
	echo "[$(date)] $MESSAGE" >> "$LOG_FILE"
}

# Send email notification in case of backup failure
send_failure_email() {
	local site="$1"
	local type="$2" # daily,weekly,monthly
	local component="$3" # db or files
	local reason="$4"

	local timestamp
	timestamp=$(date +"%Y-%m-%d %H:%M:%S")

	# HTML message
	local html_body
	html_body="
	<html>
	<body style=\"font-family:Arial, sans-serif;\">
		<h2 style=\"color:#d9534f;\">⚠️ Failed Backup Alert</h2>
		<p><strong>Site:</strong> $site<br>
        	<strong>Backup type:</strong> $type<br>
        	<strong>Component:</strong> $component<br>
        	<strong>Error:</strong> $reason</p>
		<hr>
        	<p style=\"font-size:12px;color:gray;\">
            		Host: $HOSTNAME<br>
			IP: $SERVER_IP<br>
            		Time: $timestamp
        	</p>
	</body>
	</html>
	"

	# Send with Resend API
	local response
	response=$(curl -s -X POST "https://api.resend.com/emails/batch" \
        	-H "Authorization: Bearer $API_KEY" \
        	-H "Content-Type: application/json" \
        	-d @- <<EOF
[
  {
    "from": "$FROM",
    "to": ["$TO"],
    "subject": "⚠️ $HOSTNAME: Backup failed for $site",
    "html": $(jq -Rs . <<< "$html_body")
  }
]
EOF
	)

	echo "[$(date)] Resend API Response: $response" >> "$ALERT_FILE"
}

log "=== Backup started ==="

# Determine backup type
if [ "$DAY_OF_MONTH" -eq 1 ]
then
	BACKUP_TYPE="monthly"
	RETENTION=$MONTHLY_RETENTION
elif
	[ "$DAY_OF_WEEK" -eq 7 ]
then
	BACKUP_TYPE="weekly"
	RETENTION=$WEEKLY_RETENTION
else
	BACKUP_TYPE="daily"
	RETENTION=$DAILY_RETENTION
fi

log "[+] Running $BACKUP_TYPE backup"

# Loop through sites
for SITE_CONF in "${SITES[@]}"
do
	IFS=":" read -r SITE_NAME TYPE WEBROOT DB_NAME EXTRA <<< "$SITE_CONF"
	SITE_BASE="/backups/$SITE_NAME"

	FILE_DIR="$SITE_BASE/files/$BACKUP_TYPE"
	DB_DIR="$SITE_BASE/db/$BACKUP_TYPE"

	mkdir -p "$FILE_DIR" "$DB_DIR"

	log "[+] Backing up site '$SITE_NAME'"

	# Files backup
	FILE_BACKUP="$FILE_DIR/backup_$DATE.tar.gz"
	log "	[FILES] Backing up $WEBROOT..."
	if ! tar czf "$FILE_BACKUP" "$WEBROOT" &>/dev/null
	then
		log "[ERROR] File backup failed for $SITE_NAME"
		send_failure_email "$SITE_NAME" "$BACKUP_TYPE" "files" "tar command failed"
		continue
	fi
	log "[OK] Files Backup completed: $FILE_BACKUP"

	# Db backup
	DB_BACKUP="$DB_DIR/backup_$DATE.sql.gz"

	case "$TYPE" in
		mysql)
			log "	[DB] MySQL dump for $DB_NAME..."
			if ! $MYSQLDUMP "$DB_NAME" --single-transaction | gzip > "$DB_BACKUP"
			then
				log "[ERROR] MySQL backup failed for $SITE_NAME"
				send_failure_email "$SITE_NAME" "$BACKUP_TYPE" "db" "mysqldump failed"
				continue
			fi
			#log "	[DB] MySQL dump for $DB_NAME completed: $DB_BACKUP"
			;;
		docker-postgres)
			CONTAINER="$EXTRA"
			log "	[DB] PostgreSQL dump from Docker container '$CONTAINER' (DB: $DB_NAME)..."
			if ! docker exec "$CONTAINER" pg_dump -U default "$DB_NAME" | gzip > "$DB_BACKUP"
			then
				log "[ERROR] PostgreSQL backup failed for $SITE_NAME (Docker: $CONTAINER)"
				send_failure_email "$SITE_NAME" "$BACKUP_TYPE" "db" "pg_dump failed in container $CONTAINER"
			fi
			#log "	[DB] PostgreSQL dump for $DB_NAME completed: $DB_BACKUP"
			;;
		*)
			log "[ERROR] Unknown backup type: $TYPE"
			send_failure_email "$SITE_NAME" "$BACKUP_TYPE" "db" "Unknown type: $TYPE"
			continue
			;;
	esac

	log "	[DB] Backup completed: $DB_BACKUP"

	# Cleanup old files
	log "	[CLEANUP] Removing old file backups (> $RETENTION days)"
	find "$FILE_DIR" -type f -mtime +$RETENTION -delete

	# Cleanup old db backups
	log "	[CLEANUP] Removing old db backups (> $RETENTION days)"
	find "$DB_DIR" -type f -mtime +$RETENTION -delete
done

log "=== $BACKUP_TYPE Backup completed successfully ==="
