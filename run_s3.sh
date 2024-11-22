#!/bin/bash

source ./.backupenv

# Variables
BACKUP_DIR="$HOME/aws/backups/mysqlbackup"
LOG_DIR="$HOME/aws/logs"
LOG_FILE="$LOG_DIR/backup_log.log"
ERROR_LOG_FILE="$LOG_DIR/backup_error_log.log"
UNIX_TIMESTAMP=$(date +%s)
TIMESTAMP=$(TZ=Asia/Kolkata date +\%F_\%I-\%M-\%S_\%P)

# File count Script Start

# Path to the file that stores the backup count
COUNT_FILE="$BACKUP_DIR/COUNT.txt"

# Check if the backup directory exists, create it if it doesn't
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR" || { echo "$(date): Failed to create backup directory" >> "$ERROR_LOG_FILE"; exit 1; }
fi

# Create the logs directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" || { echo "$(date): Failed to create logs directory" >> "$ERROR_LOG_FILE"; exit 1; }
fi

# Check if the count file exists, create it if it doesn't
if [ ! -f "$COUNT_FILE" ]; then
    echo 0 > "$COUNT_FILE" || { echo "$(date): Failed to create count file" >> "$ERROR_LOG_FILE"; exit 1; }
fi

# Read the current count from the file
COUNT=$(cat "$COUNT_FILE")
# Increment the count
COUNT=$((COUNT + 1))
# Save the updated count back to the file
echo $COUNT > "$COUNT_FILE" || { echo "$(date): Failed to update count file" >> "$ERROR_LOG_FILE"; exit 1; }

# File count Script End

# Timestamp for backup file
BACKUP_FILE="$BACKUP_DIR/${UNIX_TIMESTAMP}_${COUNT}_${SERVER_NAME}_${TIMESTAMP}.sql"

# Create the backup file by running mysqldump
mysqldump -u "$DB_USER" -p"$DB_PASS" --all-databases > "$BACKUP_FILE" 2>> "$ERROR_LOG_FILE"
if [ $? -ne 0 ]; then
  echo "$(date): Database backup failed" >> "$ERROR_LOG_FILE"
  exit 1
fi

# Upload to S3
aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/${SERVER_NAME}/" >> "$LOG_FILE" 2>> "$ERROR_LOG_FILE"
# Check if the upload was successful
if [ $? -eq 0 ]; then
  echo "Backup and upload successful: $(date)" >> "$LOG_FILE"
else
  echo "$(date): Upload to S3 failed" >> "$ERROR_LOG_FILE"
fi

# Activating the virtual environment
source $VENV_DIR/bin/activate || { echo "$(date): Failed to activate virtual environment" >> "$ERROR_LOG_FILE"; exit 1; }

# Python script to delete old backups from S3
python3 - <<EOF >> "$LOG_FILE" 2>> "$ERROR_LOG_FILE"
import boto3
from botocore.exceptions import NoCredentialsError
import datetime

AWS_ACCESS_KEY = "$AWS_ACCESS_KEY"
AWS_SECRET_KEY = "$AWS_SECRET_KEY"
BUCKET_NAME = "$S3_BUCKET"
FOLDER_NAME = "${SERVER_NAME}/"
BACKUPS_TO_KEEP = $BACKUPS_TO_KEEP

s3_client = boto3.client(
    's3',
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY
)

try:
    response = s3_client.list_objects_v2(Bucket=BUCKET_NAME, Prefix=FOLDER_NAME)
    if 'Contents' in response:
        backups = sorted(response['Contents'], key=lambda x: x['LastModified'], reverse=True)
        old_backups = backups[BACKUPS_TO_KEEP:]
        for backup in old_backups:
            s3_client.delete_object(Bucket=BUCKET_NAME, Key=backup['Key'])
            print(f"{datetime.datetime.now()}: Deleted {backup['Key']} from S3")
        print(f"{datetime.datetime.now()}: Cleanup complete. Kept latest {BACKUPS_TO_KEEP} backups.")
    else:
        print(f"{datetime.datetime.now()}: No backups found in the specified S3 bucket and folder.")
except NoCredentialsError:
    print(f"{datetime.datetime.now()}: AWS credentials not found.")
    exit(1)
except Exception as e:
    print(f"{datetime.datetime.now()}: An error occurred: {e}")
    exit(1)
EOF

if [ $? -ne 0 ]; then
  echo "$(date): Python cleanup script encountered an error" >> "$ERROR_LOG_FILE"
  deactivate
  exit 1
fi

# Deactivating the virtual environment
deactivate || { echo "$(date): Failed to deactivate virtual environment" >> "$ERROR_LOG_FILE"; exit 1; }

echo "Script executed successfully: $(date)" >> "$LOG_FILE"
exit 0
