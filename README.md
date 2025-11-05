## A. Project Overview

### What does this script do?

This script automatically creates compressed backups (`.tar.gz`) of your chosen folders. It also generates checksum files to ensure data integrity, keeps only recent backups (rotation), and provides options to restore or list backups.

### Why is it useful?

Manual backups are time-consuming and error-prone. This script saves time by:

* Running automatically with one command
* Verifying backup integrity
* Cleaning old backups automatically
* Preventing accidental multiple runs with a lockfile
* Supporting dry-run mode for testing

---

## B. How to Use It

### Installation Steps

1. Clone or copy the script to your local machine.
2. Make the script executable:

   ```bash
   chmod +x backup.sh
   ```
3. Create a `backup.config` file in the same folder:

   ```bash
   BACKUP_DESTINATION="/home/user/backups"
   EXCLUDE_PATTERNS="*.tmp,*.log"
   DAILY_KEEP=3
   WEEKLY_KEEP=2
   MONTHLY_KEEP=2
   CHECKSUM_CMD="sha256sum"
   ```

### Basic Usage Examples

* **Create a new backup:**

  ```bash
  ./backup.sh --backup /home/user/data
  ```
* **Restore a backup:**

  ```bash
  ./backup.sh --restore /home/user/backups/backup-2025-11-05-1130.tar.gz /tmp/restore
  ```
* **List all backups:**

  ```bash
  ./backup.sh --list
  ```
* **Dry-run mode (no actual backup created):**

  ```bash
  ./backup.sh --dry-run --backup /home/user/data
  ```

### All Command Options

| Command                            | Description                              |
| ---------------------------------- | ---------------------------------------- |
| `--backup <src_dir>`               | Create a compressed backup               |
| `--restore <archive> <target_dir>` | Restore files from a backup              |
| `--list`                           | Show available backups                   |
| `--dry-run`                        | Simulate actions without performing them |

---

## C. How It Works

### Rotation Algorithm

1. The script lists all backups by date.
2. It keeps only a limited number of daily, weekly, and monthly backups:

   * Keeps `DAILY_KEEP` most recent days.
   * Keeps `WEEKLY_KEEP` most recent weeks.
   * Keeps `MONTHLY_KEEP` most recent months.
3. Older backups are deleted automatically unless in dry-run mode.

### Checksum Creation

After each backup, the script creates a checksum file using:

```bash
sha256sum backup.tar.gz > backup.tar.gz.md5
```

It then verifies the checksum to confirm the backup was created correctly.

### Folder Structure

Example backup folder:

```
/home/user/backups/
├── backup-2025-11-01-0900.tar.gz
├── backup-2025-11-01-0900.tar.gz.md5
├── backup-2025-11-02-0900.tar.gz
├── backup-2025-11-02-0900.tar.gz.md5
└── backup.log
```

---

## D. Design Decisions

### Why This Approach?

* Bash is available on all Linux systems, no need for extra software.
* `tar` and `sha256sum` are reliable and fast.
* Configuration file makes it flexible for different systems.

### Challenges Faced

1. **Preventing parallel backups** – Solved using a lock file `/tmp/backup.lock`.
2. **Handling errors safely** – Used `set -euo pipefail` and proper logging.
3. **Backup rotation** – Designed a clear logic using daily/weekly/monthly tags.

---

## E. Testing

### How the Script Was Tested

1. Created a test folder with files:

   ```bash
   mkdir test_data && echo "hello" > test_data/file1.txt
   ```
2. Ran the following commands:

   ```bash
   ./backup.sh --backup test_data
   ./backup.sh --list
   ./backup.sh --dry-run --backup test_data
   ./backup.sh --restore /home/user/backups/backup-2025-11-05-1130.tar.gz /tmp/restore
   ```

### Example Outputs

**Creating Backup:**

```
[2025-11-05 11:30:00] INFO: Starting backup of test_data -> backup-2025-11-05-1130.tar.gz
[2025-11-05 11:30:10] SUCCESS: Backup created: backup-2025-11-05-1130.tar.gz
[2025-11-05 11:30:11] INFO: Checksum verified successfully
[2025-11-05 11:30:12] INFO: Archive extraction test succeeded
```

**Dry Run Example:**

```
[2025-11-05 11:32:00] DRY: Would run: tar -czf backup.tar.gz -C /test_data
```

**Error Handling Example (invalid folder):**

```
Error: Source folder not found: /fake/folder
```

**Automatic Deletion Example:**

```
[2025-11-05 11:33:00] INFO: Deleted old backup backup-2025-10-15-0900.tar.gz
```

---

## F. Known Limitations

* Currently supports **one source folder** per run.
* Backup rotation is based only on file timestamps (not actual creation time).
* Does not yet support **remote upload** (e.g., AWS S3 or SSH).
* No email or notification system for success/failure yet.

### Possible Improvements

* Add remote cloud backup support (AWS, Google Drive, etc.)
* Add scheduling via `cron`
* Add color-coded log output for better readability
