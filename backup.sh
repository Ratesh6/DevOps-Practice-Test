#!/usr/bin/env bash
# ============================================================
# Automated Backup System
# Features:
# - Configurable via backup.config
# - Creates compressed backups (.tar.gz)
# - Generates and verifies checksums
# - Rotation: keeps daily, weekly, monthly backups
# - Logging with timestamps
# - Dry-run mode
# - Restore and list backups
# - Lockfile to prevent parallel runs
# ============================================================

set -euo pipefail

# --- Load Config ---
CONFIG_FILE="$(dirname "$0")/backup.config"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file not found: $CONFIG_FILE"
  exit 1
fi
source "$CONFIG_FILE"

# --- Variables ---
LOG_FILE="$BACKUP_DESTINATION/backup.log"
LOCK_FILE="/tmp/backup.lock"
DRY_RUN=false
CHECKSUM_CMD="${CHECKSUM_CMD:-sha256sum}"

# --- Helper Functions ---
timestamp() { date +"%Y-%m-%d-%H%M"; }

log() {
  local level="$1"; shift
  echo "[$(date '+%F %T')] $level: $*" | tee -a "$LOG_FILE"
}

error_exit() {
  log "ERROR" "$1"
  [ -f "$LOCK_FILE" ] && rm -f "$LOCK_FILE"
  exit 1
}

make_exclude_args() {
  local IFS=','; read -ra parts <<< "$EXCLUDE_PATTERNS"
  for p in "${parts[@]}"; do
    printf -- '--exclude=%s\n' "$p"
  done
}

verify_checksum() {
  local archive="$1" mdfile="$2"
  $CHECKSUM_CMD -c "$mdfile" &>/dev/null
}

test_extract() {
  local archive="$1"
  tar -tzf "$archive" &>/dev/null
}

list_backups() {
  ls -1t "$BACKUP_DESTINATION"/backup-*.tar.gz 2>/dev/null || true
}

# --- Lock Handling ---
acquire_lock() {
  if [ -f "$LOCK_FILE" ]; then
    log "ERROR" "Backup already running. Lock file exists: $LOCK_FILE"
    exit 1
  fi
  echo $$ > "$LOCK_FILE"
}

release_lock() {
  rm -f "$LOCK_FILE"
}

trap 'release_lock' EXIT

# --- Core Functions ---
create_backup() {
  local src="$1"

  [ ! -d "$src" ] && error_exit "Source folder not found: $src"
  mkdir -p "$BACKUP_DESTINATION"

  local TS name dest
  TS=$(timestamp)
  name="backup-${TS}.tar.gz"
  dest="$BACKUP_DESTINATION/$name"

  local exclude_args
  IFS=$'\n' read -d '' -r -a exclude_args < <(make_exclude_args && printf '\0')

  log "INFO" "Starting backup of $src -> $dest"

  if [ "$DRY_RUN" = true ]; then
    log "DRY" "Would run: tar -czf $dest ${exclude_args[*]} -C $(dirname "$src") $(basename "$src")"
    return
  fi

  tar -czf "$dest" ${exclude_args[*]} -C "$(dirname "$src")" "$(basename "$src")" || error_exit "tar failed"
  log "SUCCESS" "Backup created: $name"

  # Create checksum
  if $CHECKSUM_CMD "$dest" > "$dest.md5"; then
    log "INFO" "Checksum file created: $(basename "$dest.md5")"
  else
    log "ERROR" "Failed to create checksum for $name"
  fi

  # Verify checksum
  if verify_checksum "$dest" "$dest.md5"; then
    log "INFO" "Checksum verified successfully"
  else
    log "ERROR" "Checksum verification FAILED for $name"
    echo "FAILED"
    return 1
  fi

  # Test extract
  if test_extract "$dest"; then
    log "INFO" "Archive extraction test succeeded"
    echo "SUCCESS"
  else
    log "ERROR" "Archive extraction test FAILED for $name"
    echo "FAILED"
    return 1
  fi
}

restore_backup() {
  local archive="$1"
  local todir="$2"
  if [ ! -f "$archive" ]; then
    error_exit "Restore failed: archive not found: $archive"
  fi
  if [ "$DRY_RUN" = true ]; then
    log "DRY" "Would extract $archive to $todir"
  else
    mkdir -p "$todir"
    tar -xzf "$archive" -C "$todir" || error_exit "Restore failed: tar extraction failed"
    log "SUCCESS" "Restored $archive to $todir"
  fi
}

show_list() {
  echo "Available backups (newest first):"
  for f in $(list_backups); do
    local size
    size=$(du -h "$f" | cut -f1)
    echo "$(basename "$f") - $size"
  done
}

rotate_backups() {
  log "INFO" "Starting rotation"
  mapfile -t backups < <(list_backups)
  (( ${#backups[@]} == 0 )) && { log "INFO" "No backups to rotate"; return; }

  local keep_daily keep_weekly keep_monthly
  keep_daily=()
  keep_weekly=()
  keep_monthly=()

  for f in "${backups[@]}"; do
    local date=$(echo "$f" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')
    [ -z "$date" ] && continue

    local day week month
    day=$(date -d "$date" +%Y-%m-%d)
    week=$(date -d "$date" +%G-%V)
    month=$(date -d "$date" +%Y-%m)

    if (( ${#keep_daily[@]} < DAILY_KEEP )) && [[ ! " ${keep_daily[*]} " =~ $day ]]; then
      keep_daily+=("$day")
      continue
    fi
    if (( ${#keep_weekly[@]} < WEEKLY_KEEP )) && [[ ! " ${keep_weekly[*]} " =~ $week ]]; then
      keep_weekly+=("$week")
      continue
    fi
    if (( ${#keep_monthly[@]} < MONTHLY_KEEP )) && [[ ! " ${keep_monthly[*]} " =~ $month ]]; then
      keep_monthly+=("$month")
      continue
    fi

    if [ "$DRY_RUN" = true ]; then
      log "DRY" "Would delete old backup $f"
    else
      rm -f "$f" "$f.md5"
      log "INFO" "Deleted old backup $f"
    fi
  done

  log "SUCCESS" "Rotation completed"
}

# --- CLI Entry Point ---
main() {
  acquire_lock

  local cmd="$1"; shift || true

  case "$cmd" in
    --backup)
      local src="$1"
      [ -z "$src" ] && error_exit "Usage: $0 --backup /path/to/source"
      create_backup "$src"
      rotate_backups
      ;;
    --restore)
      local archive="$1"; local todir="$2"
      [ -z "$archive" ] || [ -z "$todir" ] && error_exit "Usage: $0 --restore backup.tar.gz /path/to/restore"
      restore_backup "$archive" "$todir"
      ;;
    --list)
      show_list
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      main "$@"
      ;;
    *)
      echo "Usage:"
      echo "  $0 --backup <src_dir>"
      echo "  $0 --restore <archive> <target_dir>"
      echo "  $0 --list"
      echo "  $0 --dry-run --backup <src_dir>"
      ;;
  esac
}

main "$@"
