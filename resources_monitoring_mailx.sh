#!/bin/bash

# Script to check CPU, Memory and Storage and send alerts by email

# Basic Settings
HOSTNAME=$(hostname)
ALERT_FILE=/var/log/resources_monitoring/alerts.log
ALERT_STATUS_DIR=/var/log/resources_monitoring/status
EMAIL="" # Add desired email recipients separated with commas


# Create status dir
mkdir -p "$ALERT_STATUS_DIR"

# Thresholds

CPU_THRESHOLD=70
MEM_THRESHOLD=90
DISK_THRESHOLD=85

# Get current usage

CPU_IDLE=$(top -bn2 -d 1 | grep "Cpu(s)" | tail -n1 | sed -n 's/.*, *\([0-9.]*\) *id.*/\1/p')
CPU_USAGE=$(printf "%.0f" "$(echo "100 - $CPU_IDLE" | bc)")
MEM_USAGE=$(free | awk '/Mem/ {printf("%.0f"), $3/$2 * 100}')

# Partitions

ROOT_PART_USAGE=$(df -h / | awk 'NR==2 {gsub("%",""); print $5}')
VAR_PART_USAGE=$(df -h /var | awk 'NR==2 {gsub("%",""); print $5}')
TMP_PART_USAGE=$(df -h /tmp | awk 'NR==2 {gsub("%",""); print $5}')
HOME_PART_USAGE=$(df -h /home | awk 'NR==2 {gsub("%",""); print $5}')

log_skipped_alert() {

	local type=$1
	echo "[$(date)] Skipped alert for $type: already sent." >> "$ALERT_FILE"
}

send_alert() {
	
	local type=$1
	local usage=$2
	local status_file="${ALERT_STATUS_DIR}/${type}.status"

	# Skip if alert already sent

	if [ -f "$status_file" ]
	then
		log_skipped_alert "$type"
		return
	fi

	touch "$status_file"

	local message="[$(date)] ALERT on $HOSTNAME: $type usage is at ${usage}%"

	echo "$message" >> "$ALERT_FILE"

	case $type in

		"CPU")
			echo "Highest CPU-consuming processes:" >> "$ALERT_FILE"
			ps -eo pid,ppid,cmd,user,%cpu --sort=-%cpu | head -n 10 >> "$ALERT_FILE"
			;;
		"Memory")
			echo "Highest memory-consuming processes:" >> "$ALERT_FILE"
			ps -eo pid,ppid,cmd,user,%mem --sort=-%mem | head -n 10 >> "$ALERT_FILE"
			;;
		"root_partition")
			echo "root partition space used:" >> "$ALERT_FILE"
			df -h / >> "$ALERT_FILE"
			;;
		"var_partition")
                	echo "var partition space used:" >> "$ALERT_FILE"
                	df -h /var >> "$ALERT_FILE"
			;;
		"tmp_partition")
                	echo "tmp partition space used:" >> "$ALERT_FILE"
                	df -h /tmp >> "$ALERT_FILE"
			;;
		"home_partition")
                	echo "home partition space used:" >> "$ALERT_FILE"
                	df -h /home >> "$ALERT_FILE"
			;;
	esac

	echo "--------------------------------" >> "$ALERT_FILE"

	echo "$message" | mailx -a "From: Server Name Alert <alert@domain.com>" -s "⚠️  $HOSTNAME: High $type usage alert" "$EMAIL" # Add desired From email address
}

# Trigger alerts

[ "$CPU_USAGE" -gt "$CPU_THRESHOLD" ] && send_alert "CPU" "$CPU_USAGE"
#[ "$MEM_USAGE" -gt "$MEM_THRESHOLD" ] && send_alert "Memory" "$MEM_USAGE"
[ "$ROOT_PART_USAGE" -gt "$DISK_THRESHOLD" ] && send_alert "root_partition" "$ROOT_PART_USAGE"
[ "$VAR_PART_USAGE" -gt "$DISK_THRESHOLD" ] && send_alert "var_partition" "$VAR_PART_USAGE"
[ "$TMP_PART_USAGE" -gt "$DISK_THRESHOLD" ] && send_alert "tmp_partition" "$TMP_PART_USAGE"
[ "$HOME_PART_USAGE" -gt "$DISK_THRESHOLD" ] && send_alert "home_partition" "$HOME_PART_USAGE"

# Clear status file when usage drops below threshold
[ "$CPU_USAGE" -le "$CPU_THRESHOLD" ] && rm -f "$ALERT_STATUS_DIR/CPU.status"
#[ "$MEM_USAGE" -le "$MEM_THRESHOLD" ] && rm -f "$ALERT_STATUS_DIR/Memory.status"
[ "$ROOT_PART_USAGE" -le "$DISK_THRESHOLD" ] && rm -f "$ALERT_STATUS_DIR/root_partition.status"
[ "$VAR_PART_USAGE" -le "$DISK_THRESHOLD" ] && rm -f "$ALERT_STATUS_DIR/var_partition.status"
[ "$TMP_PART_USAGE" -le "$DISK_THRESHOLD" ] && rm -f "$ALERT_STATUS_DIR/tmp_partition.status"
[ "$HOME_PART_USAGE" -le "$DISK_THRESHOLD" ] && rm -f "$ALERT_STATUS_DIR/home_partition.status"

