#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

OLD_CRT=/usr/local/share/ca-certificates/localhost.crt

if [ -f "$OLD_CRT" ]; then
    echo "Removing old development certificate anchor..."
    $SUDO rm "$OLD_CRT"
fi

$SUDO rm -f /etc/ssl/certs/dotnet-devcert.pem

echo "Installing development CA into system trust store..."

$SUDO cp "$CA_CRT" /usr/local/share/ca-certificates/localhost-dev-ca.crt
$SUDO update-ca-certificates

configure_nssdb() {
    echo "Configuring NSS database: $1"

    certutil -d "sql:$1" \
        -D -n localhost-dev-ca >/dev/null 2>&1 || true

    certutil -d "sql:$1" \
        -A \
        -t "C,," \
        -n localhost-dev-ca \
        -i "$CA_CRT"
}

NSSDB_PATHS="$HOME/.pki/nssdb
$HOME/snap/chromium/current/.pki/nssdb
$HOME/snap/postman/current/.pki/nssdb"

for NSSDB in $NSSDB_PATHS; do
    if [ -d "$NSSDB" ]; then
        configure_nssdb "$NSSDB"
    fi
done

echo ""
echo "Development CA successfully installed!"
echo ""
echo "CA certificate: $CA_CRT"
echo "Server PFX:     $PFX_PATH"
echo ""
echo "Configure your Docker container to use the generated PFX."
