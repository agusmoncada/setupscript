#!/bin/bash

LOGFILE="/var/log/odoo_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Inicio de instalación de dependencias para Odoo 16 con localización argentina."

log "Actualizando paquetes del sistema."
apt update -y

log "Instalando dependencias del sistema."
apt install -y git python3-pip libxml2-dev libxslt1-dev libldap2-dev libsasl2-dev libssl-dev libffi-dev libjpeg-dev libpq-dev gcc g++ python3-dev libxmlsec1-dev libxmlsec1-openssl libfreetype6-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libxmlsec1 libxmlsec1-dev libxmlsec1-openssl

log "Actualizando pip, setuptools y wheel."
pip install --upgrade pip wheel

log "Forzando setuptools 58.0.4 para compatibilidad con pysimplesoap."
pip install setuptools==58.0.4

log "Corrigiendo requirements.txt para evitar errores con M2Crypto, PySimpleSOAP y PyAfipWs."
REQUIREMENTS_TMP="/tmp/requirements-argentina.txt"
cat <<EOF > "$REQUIREMENTS_TMP"
# Dependencias necesarias para Odoo Argentina - corregidas
GitPython
suds-community
paramiko
pyopenssl
cryptography
python-barcode
reportlab
pyserial
qrcode
fpdf
# Comentamos M2Crypto y PyAfipWs por instalación directa
git+https://github.com/ingadhoc/pyafipws.git@py3k  # ahora lo instalamos aparte
EOF

log "Instalando requerimientos de odoo-argentina."
pip install -r "$REQUIREMENTS_TMP" || { log "Error: Instalación de requerimientos de odoo-argentina falló."; exit 1; }

log "Instalando pysimplesoap desde commit conocido."
pip install "git+https://github.com/pysimplesoap/pysimplesoap.git@31c85822dec55de8df947a62db99a298b4aa1a51" || { log "Error: Instalación de pysimplesoap falló."; exit 1; }

log "Instalando PyAfipWs desde fork con fix de setuptools."
pip install "git+https://github.com/agusmoncada/pyafipws.git@py3k" || { log "Error: Instalación de pyafipws falló."; exit 1; }

log "Instalación finalizada exitosamente."
exit 0
