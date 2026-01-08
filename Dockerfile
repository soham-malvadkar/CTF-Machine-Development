FROM python:3.9-slim

# Install system dependencies
# netcat: for reverse shell
# cron: for privesc
# sudo: for user management
# iproute2: for ip command (debugging)
RUN apt-get update && apt-get install -y \
    netcat-openbsd \
    iproute2 \
    sudo \
    cron \
    procps \
    nano \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Create CTF user
RUN useradd -m -s /bin/bash ctfuser
RUN echo "ctfuser:SuperSecurePassword123!" | chpasswd

# Setup Flags
RUN echo "CTF{w3b_f00th0ld_ach13v3d}" > /home/ctfuser/user.txt
RUN chown ctfuser:ctfuser /home/ctfuser/user.txt
RUN chmod 600 /home/ctfuser/user.txt

RUN echo "CTF{r00t_pr1v1l3g3_3sc4l4t10n}" > /root/root.txt
RUN chmod 600 /root/root.txt

# Setup Application
WORKDIR /app
COPY app/ .
RUN pip install -r requirements.txt

# Fix permissions
# Provide config.py that is readable by www-data (and consequently others) but we want ctfuser to find creds in it.
# We will run the flask app as www-data (or root, then drop? No, simply use USER instruction is safer for container, but for CTF we want to simulate a real server where service runs as www-data)
# Actually, standard python container runs as root. We should manually create www-data user usage.
# But for simplicity in this container, let's start as root (entrypoint) and then switch to www-data for the app.

# Create script directory for Privesc
RUN mkdir -p /opt/scripts
COPY scripts/backup.sh /opt/scripts/backup.sh
# Vulnerability: backup.sh is owned by ctfuser (or writable by ctfuser) and runs as root via cron
RUN chown ctfuser:ctfuser /opt/scripts/backup.sh
RUN chmod 777 /opt/scripts/backup.sh  
# 777 is a bit too obvious/broad? Maybe 755 and owned by ctfuser? 
# If ctfuser is target for privesc from www-data, then www-data shouldn't be able to write to it.
# Wait, the path is: Web -> www-data -> (read config) -> su ctfuser -> (edit script) -> root.
# So backup.sh needs to be writable by ctfuser.
RUN chmod 744 /opt/scripts/backup.sh

# Setup CRON
# Add a cron job that runs /opt/scripts/backup.sh every minute as root.
RUN echo "* * * * * root /bin/bash /opt/scripts/backup.sh" >> /etc/crontab

# Setup Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose port
EXPOSE 5000

ENTRYPOINT ["/entrypoint.sh"]
