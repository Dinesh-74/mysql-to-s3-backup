#!/bin/bash

# Define the virtual environment directory
VENV_DIR="venv"

# Check if the python3-venv package is installed
if ! dpkg -l | grep -q python3-venv; then
    echo "python3-venv package not found. Installing it..."
    sudo apt update
    sudo apt install -y python3-venv
else
    echo "python3-venv package is already installed."
fi

# Create a virtual environment
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "Virtual environment created in $VENV_DIR."
else
    echo "Virtual environment already exists in $VENV_DIR."
fi

# Activate the virtual environment
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Upgrade pip to the latest version
echo "Upgrading pip..."
pip install --upgrade pip

# Install required Python packages
echo "Installing required Python packages..."
pip install boto3

# Provide feedback to the user
echo "Virtual environment setup complete. Required packages installed."

# Deactivating the virtual environment
deactivate

# Check if run_s3.sh and cron.sh have execute permissions
for FILE in ./run_s3.sh ./cron.sh; do
    if [ -f "$FILE" ]; then
        if [ ! -x "$FILE" ]; then
            echo "$FILE does not have execute permissions. Adding execute permissions..."
            sudo chmod +x "$FILE"
        else
            echo "$FILE already has execute permissions."
        fi
    else
        echo "$FILE does not exist. Please ensure the file is present."
    fi
done

# Create .backupenv file
BACKUP_ENV_FILE=".backupenv"
# Function to get user input with validation
get_input() {
    local var_name="$1"
    local prompt="$2"
    local value=""
    while [ -z "$value" ]; do
        read -p "$prompt" value
        if [ -z "$value" ]; then
            echo "$var_name cannot be empty. Please enter a valid value."
        fi
    done
    echo "$value"
}

AWS_ACCESS_KEY=$(get_input "AWS Access Key" "Enter AWS Access Key: ")
AWS_SECRET_KEY=$(get_input "AWS Secret Key" "Enter AWS Secret Key: ")
S3_BUCKET=$(get_input "S3 Bucket Name" "Enter S3 Bucket Name: ")
BACKUPS_TO_KEEP=$(get_input "Number of Backups to Keep" "Enter Number of Backups to Keep: ")
DB_USER=$(get_input "Database Username" "Enter Database Username: ")
DB_PASS=$(get_input "Database Password" "Enter Database Password: ")
DB_HOST=$(get_input "Database Host" "Enter Database Host (e.g., 127.0.0.1): ")
SERVER_NAME=$(get_input "Server Name" "Enter Server Name (e.g., testingmysql): ")

cat > $BACKUP_ENV_FILE <<EOL
# AWS Credentials
AWS_ACCESS_KEY="$AWS_ACCESS_KEY" # Access Key
AWS_SECRET_KEY="$AWS_SECRET_KEY" # Secret Key

# S3 Bucket Details
S3_BUCKET="$S3_BUCKET" # s3 Bucket Name
BACKUPS_TO_KEEP=$BACKUPS_TO_KEEP # Number of Backups to keep

# Server Variables
DB_USER="$DB_USER" # Database Username
DB_PASS="$DB_PASS" # Database Password
DB_HOST="$DB_HOST" # Database Host
SERVER_NAME="$SERVER_NAME" # Current Server Name (Used in s3 bucket folder)
EOL

echo "$BACKUP_ENV_FILE created successfully!"

# Create .cronenv file
CRON_ENV_FILE=".cronenv"
echo "Creating $CRON_ENV_FILE..."

USER_HOME=$(eval echo "~$USER")
cat > $CRON_ENV_FILE <<EOL
JOB_PATH="$USER_HOME/mysql-to-s3-backup/run_s3.sh" # path to the script
LOG_PATH="$USER_HOME/aws/logs/cron_log.log"
EOL

echo "$CRON_ENV_FILE created successfully!"

echo "Activating cronjob"
# Check if cron.sh exists and has execute permissions
if [ -f ./cron.sh ]; then
    echo "Activating cronjob..."
    ./cron.sh
else
    echo "Error: cron.sh not found in the current directory."
    exit 1
fi

# Usage Reminder
echo "To activate the virtual environment, run: source $VENV_DIR/bin/activate"