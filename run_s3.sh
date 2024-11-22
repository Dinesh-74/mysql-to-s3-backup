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
    mkdir -p "$BACKUP_DIR"
fi

# Create the logs directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi

# Check if the count file exists, create it if it doesn't
if [ ! -f "$COUNT_FILE" ]; then
    echo 0 > "$COUNT_FILE"
fi


# Read the current count from the file
COUNT=$(cat "$COUNT_FILE")
# Increment the count
COUNT=$((COUNT + 1))
# Save the updated count back to the file
echo $COUNT > "$COUNT_FILE"

# File count Script End

# Timestamp for backup file
BACKUP_FILE="$BACKUP_DIR/${UNIX_TIMESTAMP}_${COUNT}_${SERVER_NAME}_${TIMESTAMP}.sql"

# Create the backup file by running mysqldump
mysqldump -u "$DB_USER" -p"$DB_PASS" --all-databases > "$BACKUP_FILE" 2>> "$ERROR_LOG_FILE"

# Check if the backup was successful
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

#Activating the virtual environment
source $VENV_DIR/bin/activate

# Python script to delete old backups from S3
python3 - <<EOF >> "$LOG_FILE" 2>> "$ERROR_LOG_FILE"
import boto3
from botocore.exceptions import NoCredentialsError
import datetime

# AWS credentials
AWS_ACCESS_KEY = "$AWS_ACCESS_KEY"
AWS_SECRET_KEY = "$AWS_SECRET_KEY"
BUCKET_NAME = "$S3_BUCKET"
FOLDER_NAME = "${SERVER_NAME}/"
BACKUPS_TO_KEEP = $BACKUPS_TO_KEEP

# Initialize S3 client
s3_client = boto3.client(
    's3',
    aws_access_key_id=AWS_ACCESS_KEY,
    aws_secret_access_key=AWS_SECRET_KEY
)

try:
    # List objects in the specified bucket and folder
    response = s3_client.list_objects_v2(Bucket=BUCKET_NAME, Prefix=FOLDER_NAME)

    # Extract the list of files and sort by LastModified in descending order (latest first)
    if 'Contents' in response:
        backups = sorted(response['Contents'], key=lambda x: x['LastModified'], reverse=True)
        
        # Delete files older than the 5 most recent ones
        old_backups = backups[BACKUPS_TO_KEEP:]
        for backup in old_backups:
            s3_client.delete_object(Bucket=BUCKET_NAME, Key=backup['Key'])
            print(f"{datetime.datetime.now()}: Deleted {backup['Key']} from S3")

        print(f"{datetime.datetime.now()}: Cleanup complete. Kept latest 5 backups.")
    else:
        print(f"{datetime.datetime.now()}: No backups found in the specified S3 bucket and folder.")

except NoCredentialsError:
    print(f"{datetime.datetime.now()}: AWS credentials not found.")
except Exception as e:
    print(f"{datetime.datetime.now()}: An error occurred: {e}")
EOF

# Deactivating the virtual environment
deactivate
# End of Script