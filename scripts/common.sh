
#!/bin/sh
set -eu

SAVE=0

usage() {
    echo "Usage: $0 [-s]"
    echo "Generates a local development CA and a valid localhost HTTPS certificate."
    echo "  -s: Also copies generated certificates to your home directory."
    exit 1
}

while getopts "sh" opt; do
    case "$opt" in
        s) SAVE=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Persistent CA storage
STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dotnet-devcert"

# PFX output for ASP.NET Core / Docker
OUTPUT_DIR="$HOME/.aspnet/https"
PFX_PATH="${PFX_PATH:-$OUTPUT_DIR/localhost.pfx}"

mkdir -p "$STATE_DIR" "$OUTPUT_DIR"
chmod 700 "$STATE_DIR" "$OUTPUT_DIR"

CA_KEY="$STATE_DIR/localhost-ca.key"
CA_CRT="$STATE_DIR/localhost-ca.crt"

TMP_PATH="$(mktemp -d)"
trap 'rm -rf "$TMP_PATH"' EXIT HUP INT TERM

KEYFILE="$TMP_PATH/localhost.key"
CRTFILE="$TMP_PATH/localhost.crt"
CSRFILE="$TMP_PATH/localhost.csr"
CONF_PATH="$TMP_PATH/localhost.conf"

# Configure privilege escalation
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

# Generate the CA only once.
# Keep its key so future certificates can be signed by the same CA.
if [ ! -f "$CA_KEY" ] && [ ! -f "$CA_CRT" ]; then
    echo "Generating development CA..."

    openssl req -x509 \
        -newkey rsa:3072 \
        -sha256 \
        -nodes \
        -days 3650 \
        -keyout "$CA_KEY" \
        -out "$CA_CRT" \
        -subj "/CN=Local Development CA" \
        -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
        -addext "keyUsage=critical,keyCertSign,cRLSign" \
        -addext "subjectKeyIdentifier=hash"

    chmod 600 "$CA_KEY"
    chmod 644 "$CA_CRT"

elif [ ! -f "$CA_KEY" ] || [ ! -f "$CA_CRT" ]; then
    echo "ERROR: CA key or certificate is missing."
    echo "Refusing to generate a replacement automatically."
    exit 1
fi

# Server certificate configuration
cat > "$CONF_PATH" <<'EOF'
[req]
prompt = no
distinguished_name = subject
req_extensions = request_extensions

[subject]
CN = localhost

[request_extensions]
subjectAltName = @alt_names

[server_extensions]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

echo "Generating localhost server certificate..."

# Generate server private key
openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:2048 \
    -out "$KEYFILE"

# Generate certificate signing request
openssl req -new \
    -key "$KEYFILE" \
    -out "$CSRFILE" \
    -config "$CONF_PATH"

# Sign server certificate with our development CA
SERIAL="$(openssl rand -hex 16)"

openssl x509 -req \
    -in "$CSRFILE" \
    -CA "$CA_CRT" \
    -CAkey "$CA_KEY" \
    -set_serial "0x$SERIAL" \
    -out "$CRTFILE" \
    -days 397 \
    -sha256 \
    -extfile "$CONF_PATH" \
    -extensions server_extensions

# Verify certificate before exporting it
openssl verify \
    -CAfile "$CA_CRT" \
    -purpose sslserver \
    -verify_hostname localhost \
    "$CRTFILE"

# Export server certificate and CA chain into PFX
openssl pkcs12 -export \
    -out "$PFX_PATH" \
    -inkey "$KEYFILE" \
    -in "$CRTFILE" \
    -certfile "$CA_CRT" \
    -name localhost \
    -passout pass:

chmod 600 "$PFX_PATH"

# Export the public server certificate separately
SERVER_CRT_PATH="${PFX_PATH%.pfx}.crt"
cp "$CRTFILE" "$SERVER_CRT_PATH"
chmod 644 "$SERVER_CRT_PATH"

# Optional convenience copies
if [ "$SAVE" = 1 ]; then
    cp "$CA_CRT" "$HOME/localhost-ca.crt"
    cp "$CRTFILE" "$HOME/localhost.crt"
    cp "$PFX_PATH" "$HOME/localhost.pfx"

    echo "Additional copies saved in $HOME"
fi

echo ""
echo "Certificate generation successful!"
echo ""
echo "CA certificate:     $CA_CRT"
echo "CA private key:     $CA_KEY"
echo "Server certificate: $SERVER_CRT_PATH"
echo "Server PFX:         $PFX_PATH"
echo ""
echo "IMPORTANT: Only distribute the PFX to your development server."
echo "Never distribute the CA private key."
