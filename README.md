# 🖥️ Resource Monitoring and Backup Bash Scripts

A practical collection of lightweight Bash scripts for monitoring system resources and running website and DB backups on Linux servers.

This repository focuses on real-world system administration use cases: detecting high resource usage, running website and DB backups and sending alerts before problems impact production systems.

---

## ✨ Features

- 📊 Monitor CPU, memory, and disk usage
- 📥 Run automated website and DB backups
- 🚨 Automatic alerting when thresholds are exceeded
- 📧 Email notifications via:
  - `mailx`
  - Resend API (modern email delivery)
- 🔁 Smart alert suppression (no spam)
- 🧾 Logging for auditing and troubleshooting
- ⚙️  Minimal dependencies (pure Bash + standard Linux tools)

---

## 📂 Scripts Included

### 1. `resources-monitoring/resources_monitoring_mailx.sh`

Monitors:
- CPU usage
- Memory usage (currently optional)
- Disk usage (`/`, `/var`, `/tmp`, `/home`)

**Features:**
- Sends alerts using `mailx`
- Logs top processes when thresholds are exceeded
- Prevents duplicate alerts using status files

---

### 2. `resources-monitoring/resources_monitoring_resend.sh`

Monitors:
- Root (`/`) disk usage

**Features:**
- Sends HTML alerts via **Resend API**
- Includes formatted disk usage output
- Cleaner alert formatting for modern workflows

---

### 3. `backups/backup-resend-notification.sh`

**Features:**
- Website files backup
- DB backup (MySQL or PostgreSQL)
- Sends HTML failed backup alerts via **Resend API**
- Includes reason of failure

---

## ⚙️ Requirements

- Linux system
- Bash
- Common utilities:
  - `top`
  - `awk`
  - `df`
  - `ps`
  - `bc`
  - `curl`
  - `jq` (for Resend script)
- Optional:
  - `mailx` (for local email alerts)

---

## 🚀 Setup

### 1. Clone the repository

```bash
git clone https://github.com/mitch-webdev/monitoring-backup.git
cd monitoring-backup
