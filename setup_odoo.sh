#!/bin/bash

# Define log file
LOG_FILE="/var/log/odoo_install.log"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Ensure permissions to write to the log file
if [ ! -w $(dirname "$LOG_FILE") ]; then
    echo "Error: Insufficient permissions to write to $(dirname "$LOG_FILE"). Please run as root or specify a different log path." >&2
    exit 1
fi

log "Starting Odoo v16 server setup."

# Update and install system dependencies
log "Updating package list."
apt update -y >> $LOG_FILE 2>&1

log "Installing required system packages."
apt install -y build-essential swig libssl-dev python3-dev >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "Error installing system packages. Exiting."
    exit 1
fi

# Install pip and Python packages
log "Ensuring pip and setuptools are correctly installed."
python3 -m pip install --upgrade pip setuptools==57.5.0 wheel >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "Error installing pip and setuptools. Exiting."
    exit 1
fi

log "Installing Python dependencies for l10n_ar."
python3 -m pip install astor future pyOpenSSL==22.1.0 M2Crypto httplib2>=0.7 cryptography==38.0.4 git+https://github.com/pysimplesoap/pysimplesoap@e1453f385cee119bf8cfb53c763ef212652359f5 git+https://github.com/agusmoncada/pyafipws >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "Error installing Python dependencies. Exiting."
    exit 1
fi

# Set permissions for pyafipws
log "Setting permissions for pyafipws package."
PYAFIPWS_PATH=$(python3 -c "import os, pyafipws; print(os.path.dirname(pyafipws.__file__))")
sudo chown -R odoo:odoo "$PYAFIPWS_PATH" >> $LOG_FILE 2>&1
if [ $? -ne 0 ]; then
    log "Error setting permissions for pyafipws. Exiting."
    exit 1
fi

log "Setup completed successfully. Odoo server is ready."
exit 0
