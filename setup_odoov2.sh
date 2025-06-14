#!/bin/bash

# Variables de configuración
LOG_FILE="/var/log/odoo_install.log"
ODOO_USER="odoo"

# Función para registrar logs
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Función para verificar el estado de los comandos
check_status() {
    if [ $? -ne 0 ]; then
        log "Error: $1 falló. Verifique $LOG_FILE para más detalles."
        exit 1
    fi
}

# Asegurar ejecución como root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root." >&2
    exit 1
fi

log "Inicio de instalación de dependencias para Odoo 16 con localización argentina."

log "Actualizando paquetes del sistema."
apt update -y >> $LOG_FILE 2>&1
check_status "Actualización de paquetes"

log "Instalando dependencias del sistema."
apt install -y build-essential python3-dev libpq-dev libxml2-dev \
    libxslt1-dev libldap2-dev libsasl2-dev libffi-dev libssl-dev \
    python3-pip swig git python3-m2crypto >> $LOG_FILE 2>&1
check_status "Instalación de paquetes del sistema"

log "Actualizando pip, setuptools y wheel."
python3 -m pip install --upgrade pip setuptools wheel >> $LOG_FILE 2>&1
check_status "Actualización de herramientas de Python"

# Clonamos la localización argentina (repositorio CE)
cd /opt || exit 1
if [ -d "odoo-argentina" ]; then
    rm -rf odoo-argentina
fi

git clone -b 16.0 https://github.com/ingadhoc/odoo-argentina.git >> $LOG_FILE 2>&1
check_status "Clonado de odoo-argentina"

cd odoo-argentina || exit 1

log "Instalando requerimientos de odoo-argentina."
pip3 install -r requirements.txt >> $LOG_FILE 2>&1
check_status "Instalación de requerimientos de odoo-argentina"

# Instalar paquetes adicionales recomendados por comunidad
log "Instalando pysimplesoap y fpdf."
pip3 install pysimplesoap fpdf >> $LOG_FILE 2>&1
check_status "Instalación de paquetes adicionales"

# Crear carpeta cache para PyAFIPWS si no existe
PYAFIPWS_PATH=$(python3 -c "import os, pyafipws; print(os.path.dirname(pyafipws.__file__))" 2>/dev/null)
if [ -n "$PYAFIPWS_PATH" ]; then
    CACHE_DIR="$PYAFIPWS_PATH/cache"
    if [ ! -d "$CACHE_DIR" ]; then
        mkdir "$CACHE_DIR"
        chmod 777 "$CACHE_DIR"
        log "Carpeta de cache creada en $CACHE_DIR con permisos 777."
    fi
else
    log "Advertencia: pyafipws no encontrado, se omite creación de cache."
fi

# Parchear OpenSSL para compatibilidad con certificados AFIP
log "Reduciendo nivel de seguridad en OpenSSL para compatibilidad AFIP."
sed -i 's/^CipherString = DEFAULT@SECLEVEL=2/CipherString = DEFAULT@SECLEVEL=1/' /etc/ssl/openssl.cnf
check_status "Parche de OpenSSL"

# Reiniciar servicio de Odoo si existe
if systemctl list-unit-files | grep -q odoo; then
    log "Reiniciando servicio de Odoo."
    systemctl restart odoo >> $LOG_FILE 2>&1
    check_status "Reinicio de Odoo"
else
    log "Servicio Odoo no encontrado, omitiendo reinicio."
fi

log "Instalación finalizada exitosamente. Localización argentina lista para configurar en Odoo."
exit 0
