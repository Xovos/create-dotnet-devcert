
#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

OLD_CRT=/etc/ca-certificates/trust-source/localhost.p11-kit

# Remove the old certificate installed by the original script.
if [ -f "$OLD_CRT" ]; then
    echo "Removing old development certificate anchor..."
    $SUDO rm "$OLD_CRT"
fi

# Trust the CA certificate in the system trust store.
echo "Installing development CA into system trust store..."

$SUDO trust anchor --store "$CA_CRT"
$SUDO trust extract-compat

# Trust the CA in existing NSS databases.
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
