#!/bin/sh

# Define variables
RCLONE_CONFIG=/app/data/rclone.conf
DB_PATH=/app/data/kuma.db
BACKUP_PATH=/app/data/kuma_backup.db
REMOTE_PATH=r2:/$BUCKET/kuma/kuma_backup.db

# Create rclone configuration file
cat > $RCLONE_CONFIG<< EOF
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
    # Tunggu sampai tabel 'setting' ada
    while true; do
        if [ -f "$DB_PATH" ] && sqlite3 "$DB_PATH" ".tables" 2>/dev/null | grep -q "setting"; then
            echo "Database is ready!"
            return 0
        fi
        echo "Waiting for database to be ready..."
        sleep 5
    done
}

# Check if backup exists
if rclone --config $RCLONE_CONFIG ls $REMOTE_PATH; then
    # Restore if backup exists
    echo "Restoring database from backup..."
    rclone --config $RCLONE_CONFIG copyto $REMOTE_PATH $DB_PATH
else
    echo "No backup found, Uptime Kuma will create new database"
fi

# Start Uptime Kuma
echo "Starting Uptime Kuma..."
npm start &

# Tunggu sampai database siap
check_db_ready

# Tunggu tambahan untuk memastikan Uptime Kuma fully started
sleep 30

# Backup loop
while true; do
    echo "Attempting to backup database..."
    
    # Check if database exists and is ready
    if [ -f "$DB_PATH" ] && sqlite3 "$DB_PATH" ".tables" 2>/dev/null | grep -q "setting"; then
        # Create backup
        sqlite3 "$DB_PATH" ".backup \"$BACKUP_PATH\""
        
        # Upload backup
        echo "Backing up database..."
        rclone --config $RCLONE_CONFIG copyto $BACKUP_PATH $REMOTE_PATH
        echo "Backup finished at $(date)"
    else
        echo "Database not ready, skipping backup..."
    fi
    
    sleep 21600  # 6 hours
done
