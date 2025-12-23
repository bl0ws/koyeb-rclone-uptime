#!/bin/sh

# === ✅ FIX: Ensure /app/data is writable ===
mkdir -p /app/data
chmod -R u+rw /app/data

# Define variables
RCLONE_CONFIG=/app/data/rclone.conf
DB_PATH=/app/data/kuma.db
BACKUP_PATH=/app/data/kuma_backup.db
REMOTE_PATH=r2:/$BUCKET/kuma/kuma_backup.db

# Create rclone configuration file
cat > $RCLONE_CONFIG << EOF
[r2]
type = s3
provider = Other
env_auth = false
access_key_id = ${ACCESS_ID}
secret_access_key = ${ACCESS_SECRET_KEY}
endpoint = ${ENDPOINT}
EOF

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

# Restore from backup if exists
if rclone --config $RCLONE_CONFIG ls $REMOTE_PATH >/dev/null 2>&1; then
    echo "Restoring database from backup..."
    rclone --config $RCLONE_CONFIG copyto $REMOTE_PATH $DB_PATH
else
    echo "No backup found, Uptime Kuma will create new database"
fi

# Start Uptime Kuma in background
echo "Starting Uptime Kuma..."
npm start &

# Get its PID
KUMA_PID=$!

# ✅ Wait briefly, then check DB
sleep 3
check_db_ready
sleep 30

# Run backup loop in background
{
    while true; do
        echo "Attempting to backup database..."
        if [ -f "$DB_PATH" ] && sqlite3 "$DB_PATH" ".tables" 2>/dev/null | grep -q "setting"; then
            sqlite3 "$DB_PATH" ".backup \"$BACKUP_PATH\""
            rclone --config $RCLONE_CONFIG copyto $BACKUP_PATH $REMOTE_PATH
            echo "Backup finished at $(date)"
        else
            echo "Database not ready, skipping backup..."
        fi
        sleep 21600
    done
} &

# ✅ Wait for Uptime Kuma — if it exits, script exits (so container restarts)
wait $KUMA_PID
echo "Uptime Kuma exited (PID $KUMA_PID). Container will restart."
exit $?
