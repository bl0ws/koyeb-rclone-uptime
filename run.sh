#!/bin/sh
set -e

# ------------------------------
# Ensure required environment variables are set
# ------------------------------
: "${ACCESS_ID:?ACCESS_ID is not set}"
: "${ACCESS_SECRET_KEY:?ACCESS_SECRET_KEY is not set}"
: "${ENDPOINT:?ENDPOINT is not set}"
: "${BUCKET:?BUCKET is not set}"
: "${UPTIME_KUMA_PORT:=3001}"

# ------------------------------
# Define paths
# ------------------------------
RCLONE_CONFIG=/app/data/rclone.conf
DB_PATH=/app/data/kuma.db
REMOTE_PATH=r2:/$BUCKET/kuma/kuma_backup.db
BACKUP_DIR=/app/data/backups

mkdir -p $BACKUP_DIR

# ------------------------------
# Create rclone config dynamically
# ------------------------------
cat > $RCLONE_CONFIG << EOF
[r2]
type = s3
provider = Other
env_auth = false
access_key_id = ${ACCESS_ID}
secret_access_key = ${ACCESS_SECRET_KEY}
endpoint = ${ENDPOINT}
EOF

# ------------------------------
# Restore database if backup exists
# ------------------------------
echo "Checking for existing backup..."
if rclone --config $RCLONE_CONFIG ls $REMOTE_PATH >/dev/null 2>&1; then
    echo "Restoring database from backup..."
    rclone --config $RCLONE_CONFIG copy $REMOTE_PATH $DB_PATH
else
    echo "No backup found, starting with fresh database..."
fi

# ------------------------------
# Start Uptime Kuma
# ------------------------------
echo "Starting Uptime Kuma..."
npm start &

# Get PID of npm process
KUMA_PID=$!

# ------------------------------
# Wait until Uptime Kuma is ready
# ------------------------------
echo "Waiting for Uptime Kuma to start..."
while ! nc -z localhost $UPTIME_KUMA_PORT; do
    sleep 5
done
echo "Uptime Kuma is ready."

# ------------------------------
# Handle shutdown gracefully
# ------------------------------
trap "echo 'Stopping container...'; kill $KUMA_PID; wait $KUMA_PID; exit 0" SIGTERM SIGINT

# ------------------------------
# Backup loop every 12 hours
# ------------------------------
while true; do
    TIMESTAMP=$(date +%Y%m%d%H%M)
    BACKUP_FILE="$BACKUP_DIR/kuma_backup_$TIMESTAMP.db"

    echo "$(date) - Creating local backup..."
    sqlite3 $DB_PATH ".backup '$BACKUP_FILE'"

    echo "$(date) - Uploading backup to remote..."
    rclone --config $RCLONE_CONFIG copy $BACKUP_FILE $REMOTE_PATH

    echo "$(date) - Backup completed."
    sleep 43200  # 12 hours
done
