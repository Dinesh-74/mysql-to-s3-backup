#!/bin/bash

# Define the virtual environment directory
VENV_DIR="venv"

# Check if the python3.8-venv package is installed
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

# Usage Reminder
echo "To activate the virtual environment, run: source $VENV_DIR/bin/activate"
