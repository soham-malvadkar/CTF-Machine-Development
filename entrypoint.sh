#!/bin/bash

# Start cron
service cron start

# Start Flask App as www-data
# We need to make sure permissions are correct for the db
# touch /app/database.db -> Removed to let app init db
# chown www-data:www-data /app/database.db -> Not needed if we chown /app
chown -R www-data:www-data /app

echo "Starting Flask App..."
# Run as www-data user
cd /app
su -s /bin/bash -c "python3 app.py" www-data
