#!/bin/bash

source ./.cronenv

# Calculate the offset between IST and the system timezone
IST_OFFSET_HOURS=5
IST_OFFSET_MINUTES=30

# Get the system's current UTC offset in hours and minutes
SYSTEM_UTC_OFFSET=$(date +%z)
SYSTEM_OFFSET_HOURS=${SYSTEM_UTC_OFFSET:0:3}  # First 3 chars: e.g., "+05" or "-04"
SYSTEM_OFFSET_MINUTES=${SYSTEM_UTC_OFFSET:3:2} # Last 2 chars: e.g., "30" or "00"

# Calculate the adjusted hour difference between the system timezone and IST
ADJUSTED_HOURS=$((IST_OFFSET_HOURS - SYSTEM_OFFSET_HOURS))
ADJUSTED_MINUTES=$((IST_OFFSET_MINUTES - SYSTEM_OFFSET_MINUTES))

# Ensure minutes are within the 0-59 range
if [ $ADJUSTED_MINUTES -lt 0 ]; then
    ADJUSTED_MINUTES=$((60 + ADJUSTED_MINUTES))
    ADJUSTED_HOURS=$((ADJUSTED_HOURS - 1))
elif [ $ADJUSTED_MINUTES -ge 60 ]; then
    ADJUSTED_MINUTES=$((ADJUSTED_MINUTES - 60))
    ADJUSTED_HOURS=$((ADJUSTED_HOURS + 1))
fi

# Calculate the cron times based on the adjusted hours for every 6-hour interval
CRON_HOURS=$(( (24 + ADJUSTED_HOURS) % 6 ))

# Generate the final cron schedule using the adjusted hours and minutes
CRON_SCHEDULE="$ADJUSTED_MINUTES $CRON_HOURS,((CRON_HOURS+6)%24),((CRON_HOURS+12)%24),((CRON_HOURS+18)%24) * * *"

# Ensure the cron job does not already exist
(crontab -l | grep -v "$JOB_PATH") | crontab -

# Add the cron job to the crontab
(crontab -l ; echo "$CRON_SCHEDULE $JOB_PATH >> $LOG_PATH 2>&1") | crontab -

echo "Cron job scheduled to run every 6 hours in IST regardless of system timezone."