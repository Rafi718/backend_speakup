#!/bin/bash
# ============================================
# SpeakUp - Generate Cloudflare Origin Certificate
# ============================================
# Run this script to generate a self-signed certificate for development/testing
# For production, use Cloudflare Origin Certificate from dashboard

set -e

CERT_DIR="docker/caddy/certs"
DOMAIN="${1:-api.speakup.web.id}"

echo "============================================"
echo "  Generate SSL Certificate for SpeakUp"
echo "============================================"
echo ""

# Create certs directory
mkdir -p "$CERT_DIR"

# Option 1: Self-signed certificate (for testing)
echo "Generating self-signed certificate for $DOMAIN..."
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$CERT_DIR/key.pem" \
    -out "$CERT_DIR/cert.pem" \
    -subj "/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN,IP:127.0.0.1"

echo ""
echo "============================================"
echo "  Certificate generated!"
echo "============================================"
echo ""
echo "Files created:"
echo "  - $CERT_DIR/cert.pem (certificate)"
echo "  - $CERT_DIR/key.pem (private key)"
echo ""
echo "For PRODUCTION, use Cloudflare Origin Certificate:"
echo "  1. Login ke Cloudflare Dashboard"
echo "  2. SSL/TLS → Origin Server"
echo "  3. Create Certificate"
echo "  4. Download certificate dan key"
echo "  5. Replace file di $CERT_DIR/"
echo ""
echo "Setelah certificate siap, jalankan:"
echo "  docker compose build --no-cache"
echo "  docker compose up -d"
echo ""
