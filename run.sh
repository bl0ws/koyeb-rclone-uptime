#!/bin/sh

# === Ensure /app/data is writable ===
mkdir -p /app/data
chmod -R u+rw /app/data

# Define variables
DB_PATH=/app/data/kuma.db
BACKUP_PATH=/app/data/kuma_backup.db

# Restic S3 config (incremental backup)
export AWS_ACCESS_KEY_ID=${ACCESS_ID}
export AWS_SECRET_ACCESS_KEY=${ACCESS_SECRET_KEY}
export RESTIC_REPOSITORY="s3:${ENDPOINT}/${BUCKET}/kuma-restic"
export RESTIC_PASSWORD="${RESTIC_PASSWORD}"

# Init restic repo if not exists
if ! restic cat config >/dev/null 2>&1; then
    echo "Initializing restic repository..."
    restic init
fi

# Function to check if database is ready
check_db_ready() {
    while true; do
        if [ -f "$DB_PATH" ] && sqlite3 "$DB_PATH" ".tables" 2>/dev/null | grep -q "setting"; then
            echo "Database is ready!"
            return 0
        fi
        echo "Waiting for database to be ready..."
        sleep 5
    done
}

# Restore from latest restic snapshot if exists
if restic snapshots --latest 1 >/dev/null 2>&1; then
    echo "Restoring database from backup..."
    RESTORE_TMP=$(mktemp -d)
    restic restore latest --target "$RESTORE_TMP" >/dev/null 2>&1
    # Find the backed up db file (restic preserves paths)
    RESTORED_DB=$(find "$RESTORE_TMP" -name "kuma_backup.db" | head -1)
    if [ -n "$RESTORED_DB" ] && [ -f "$RESTORED_DB" ]; then
        cp "$RESTORED_DB" "$DB_PATH"
        echo "Database restored."
    else
        echo "No backup file found in snapshot."
    fi
    rm -rf "$RESTORE_TMP"
else
    echo "No backup found, Uptime Kuma will create new database"
fi

# Start Uptime Kuma in background
echo "Starting Uptime Kuma..."
npm start &

# Get its PID
KUMA_PID=$!

# Wait briefly, then check DB
sleep 3
check_db_ready
sleep 30

# Run backup loop in background (incremental via restic)
{
    while true; do
        echo "Attempting to backup database..."
        if [ -f "$DB_PATH" ] && sqlite3 "$DB_PATH" ".tables" 2>/dev/null | grep -q "setting"; then
            sqlite3 "$DB_PATH" ".backup \"$BACKUP_PATH\""
            restic backup "$BACKUP_PATH" --tag kumadb
            # Keep last 7 daily snapshots to save space
            restic forget --keep-daily 7 --prune >/dev/null 2>&1
            echo "Backup finished at $(date)"
        else
            echo "Database not ready, skipping backup..."
        fi
        sleep 21600
    done
} &

# Wait for Uptime Kuma — if it exits, script exits (so container restarts)
wait $KUMA_PID
echo "Uptime Kuma exited (PID $KUMA_PID). Container will restart."
exit $?
