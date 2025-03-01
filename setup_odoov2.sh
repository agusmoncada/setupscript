#!/bin/bash

# Define log file and Odoo specific paths
LOG_FILE="/var/log/odoo_install.log"
ODOO_CONFIG="/etc/odona/stagingryh.cloudpepper.site/odoo.conf"
ODOO_USER="odoo"
ODOO_SOURCE="/usr/lib/python3/dist-packages/odoo"

# Function to log messages
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Function to check command execution status
check_status() {
    if [ $? -ne 0 ]; then
        log "Error: $1 failed. Check $LOG_FILE for details."
        exit 1
    fi
}

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run as root" >&2
    exit 1
fi

log "Starting Odoo v16 server setup for Cloudpepper environment."

# Update and install system dependencies
log "Updating package list."
apt update -y >> $LOG_FILE 2>&1
check_status "Package update"

log "Installing required system packages."
apt install -y build-essential wget swig libssl-dev python3-dev python3-pip git >> $LOG_FILE 2>&1
check_status "System packages installation"

# Verify Python setup
log "Python version:"
python3 --version >> $LOG_FILE 2>&1

# Downgrade setuptools to a version known to work with these packages
log "Installing compatible setuptools version."
python3 -m pip install setuptools==58.0.0 wheel >> $LOG_FILE 2>&1
check_status "Setuptools and wheel installation"

log "Pip version:"
python3 -m pip --version >> $LOG_FILE 2>&1

# Install Python dependencies for l10n_ar
log "Installing Python dependencies for l10n_ar."
python3 -m pip install astor future >> $LOG_FILE 2>&1
check_status "Basic Python dependencies installation"

# Install each critical package separately with error checking
log "Installing pyOpenSSL."
python3 -m pip install pyOpenSSL==22.1.0 >> $LOG_FILE 2>&1
check_status "pyOpenSSL installation"

log "Installing M2Crypto."
python3 -m pip install M2Crypto >> $LOG_FILE 2>&1
check_status "M2Crypto installation"

log "Installing httplib2."
python3 -m pip install "httplib2>=0.7" >> $LOG_FILE 2>&1
check_status "httplib2 installation"

log "Installing cryptography."
python3 -m pip install cryptography==38.0.4 >> $LOG_FILE 2>&1
check_status "cryptography installation"

# Clone pysimplesoap manually instead of using pip
log "Installing pysimplesoap manually."
cd /tmp
if [ -d "pysimplesoap" ]; then
    rm -rf pysimplesoap
fi

git clone https://github.com/pysimplesoap/pysimplesoap.git >> $LOG_FILE 2>&1
cd pysimplesoap
git checkout e1453f385cee119bf8cfb53c763ef212652359f5 >> $LOG_FILE 2>&1

# Apply a quick fix to the setup.py file
log "Applying fix to pysimplesoap setup.py."
sed -i 's/console=\[/# console=\[/' setup.py
sed -i "s/version='.*'/version='1.08.0'/" setup.py

# Install the package
python3 setup.py install >> $LOG_FILE 2>&1
check_status "pysimplesoap manual installation"

# Install pyafipws manually too
log "Installing pyafipws manually."
cd /tmp
if [ -d "pyafipws" ]; then
    rm -rf pyafipws
fi

git clone https://github.com/agusmoncada/pyafipws.git >> $LOG_FILE 2>&1
cd pyafipws
python3 setup.py install >> $LOG_FILE 2>&1
check_status "pyafipws manual installation"

# Set permissions for pyafipws if the previous steps succeeded
log "Setting permissions for pyafipws package."
# First check if the package exists and is installed
if python3 -c "import pyafipws" &>/dev/null; then
    PYAFIPWS_PATH=$(python3 -c "import os, pyafipws; print(os.path.dirname(pyafipws.__file__))")
    
    # Check if odoo user exists before changing ownership
    if id -u $ODOO_USER >/dev/null 2>&1; then
        chown -R $ODOO_USER:$ODOO_USER "$PYAFIPWS_PATH" >> $LOG_FILE 2>&1
        check_status "Setting permissions for pyafipws"
    else
        log "Warning: $ODOO_USER user does not exist. Skipping permission setting for pyafipws."
    fi
else
    log "Warning: pyafipws module not found. Skipping permission setting."
fi

# Verify the installation
log "Verifying installations."
python3 -c "import pyafipws; print('pyafipws version:', pyafipws.__version__)" >> $LOG_FILE 2>&1
python3 -c "import pysimplesoap; print('pysimplesoap found')" >> $LOG_FILE 2>&1

# Fix any permissions issues with the Odoo directory
if [ -d "$ODOO_SOURCE" ]; then
    log "Setting correct permissions for Odoo source directory."
    chown -R $ODOO_USER:$ODOO_USER "$ODOO_SOURCE" >> $LOG_FILE 2>&1
fi

# Restart Odoo service if it exists
if systemctl list-unit-files | grep -q odoo; then
    log "Restarting Odoo service."
    systemctl restart odoo >> $LOG_FILE 2>&1
else
    log "No Odoo systemd service found. Please restart manually if needed."
fi

log "Setup completed successfully. Dependencies for Odoo l10n_ar are installed."
exit 0
