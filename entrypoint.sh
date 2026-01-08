#!/bin/bash

# Start cron
service cron start

# Start Flask App as www-data
# We need to make sure permissions are correct for the db
touch /app/database.db
chown www-data:www-data /app/database.db
chown -R www-data:www-data /app

echo "Starting Flask App..."
# Run as www-data user
su -d /app -c "python3 /app/app.py" www-data
