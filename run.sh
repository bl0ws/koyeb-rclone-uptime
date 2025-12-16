#!/bin/sh

# Define variables
RCLONE_CONFIG=/app/data/rclone.conf
DB_PATH=/app/data/kuma.db
BACKUP_PATH=/app/data/kuma_backup.db
REMOTE_PATH=r2:/$BUCKET/kuma/kuma_backup.db

#Create rclone configuration file
cat > $RCLONE_CONFIG<< EOF
[r2]
type = s3
provider = Other
env_auth = false
access_key_id = ${ACCESS_ID}
secret_access_key = ${ACCESS_SECRET_KEY}
endpoint = ${ENDPOINT}
EOF


# Check if backup exists
if rclone --config $RCLONE_CONFIG ls $REMOTE_PATH; then
    # Restore if backup exists
    echo "Restoring database from backup..."
    rclone --config $RCLONE_CONFIG copyto $REMOTE_PATH $DB_PATH
fi

# Wait for data restoration to complete
# sleep 30

# run Uptime Kuma
echo "Starting Uptime Kuma..."
npm start &

# Wait Uptime Kuma start up
sleep 60

# Back up the database every day
while true; do
    echo "Attempting to backup database..."
    # Create a backup of the database
    sqlite3 $DB_PATH ".backup \"$BACKUP_PATH\""
    # Synchronize backup files to remote storage
    echo "Backing up database..."
    rclone --config $RCLONE_CONFIG copyto $BACKUP_PATH $REMOTE_PATH
    echo "backup finish"
    sleep 86400
done
