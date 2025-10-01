#!/usr/bin/env bash
# Generate cacerts.bcfks from Temurin JRE for FIPS compliance
#
# Usage: generate-cacerts.sh <download-url>
#   download-url: Temurin JRE download URL from Adoptium API
#
# Outputs:
#   ./cacerts.bcfks - Generated BCFKS keystore

set -euo pipefail

DOWNLOAD_URL="${1:?Temurin download URL required}"

# Constants
readonly BC_FIPS_VERSION="2.1.1"
readonly BC_FIPS_URL="https://repo.maven.apache.org/maven2/org/bouncycastle/bc-fips/${BC_FIPS_VERSION}/bc-fips-${BC_FIPS_VERSION}.jar"
readonly FIPS_TRUSTSTORE_PASSWORD="changeit"

echo "Generating cacerts.bcfks from Temurin JRE"
echo "  URL: ${DOWNLOAD_URL}"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

if ! curl -fsSL --retry 3 --retry-delay 2 "$DOWNLOAD_URL" -o "${WORK_DIR}/temurin.tar.gz"; then
    echo "Failed to download Temurin JRE"
    exit 1
fi

# Extract JRE
echo "Extracting JRE..."
tar -xzf "${WORK_DIR}/temurin.tar.gz" -C "$WORK_DIR"

# Find JRE directory (should be jdk-${VERSION}-jre)
JRE_DIR=$(find "$WORK_DIR" -maxdepth 1 -type d -name "jdk-*-jre" | head -1)

if [[ ! -d "$JRE_DIR" ]]; then
    echo "JRE directory not found after extraction"
    exit 1
fi

# Verify cacerts exists
if [[ ! -f "${JRE_DIR}/lib/security/cacerts" ]]; then
    echo "cacerts not found in JRE"
    exit 1
fi

echo "✅ JRE extracted to: ${JRE_DIR}"

# Download BouncyCastle FIPS JAR
echo "Downloading BouncyCastle FIPS v${BC_FIPS_VERSION}..."
if ! curl -fsSL --retry 3 --retry-delay 2 "$BC_FIPS_URL" -o "${WORK_DIR}/bc-fips.jar"; then
    echo "Failed to download BouncyCastle FIPS JAR"
    exit 1
fi

# Convert cacerts from JKS to BCFKS
echo "Converting cacerts to BCFKS format..."
if ! "${JRE_DIR}/bin/keytool" -importkeystore \
    -srckeystore "${JRE_DIR}/lib/security/cacerts" \
    -srcstoretype JKS \
    -srcstorepass "${FIPS_TRUSTSTORE_PASSWORD}" \
    -destkeystore "${WORK_DIR}/cacerts.bcfks" \
    -deststoretype BCFKS \
    -deststorepass "${FIPS_TRUSTSTORE_PASSWORD}" \
    -providername BCFIPS \
    -providerclass org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider \
    -providerpath "${WORK_DIR}/bc-fips.jar" \
    -noprompt 2>/dev/null; then
    echo "Failed to convert cacerts to BCFKS format"
    exit 1
fi

# Verify the conversion
if [[ ! -f "${WORK_DIR}/cacerts.bcfks" ]]; then
    echo "BCFKS cacerts not created"
    exit 1
fi

# Get certificate count for verification
CERT_COUNT=$("${JRE_DIR}/bin/keytool" -list \
    -keystore "${WORK_DIR}/cacerts.bcfks" \
    -storepass "${FIPS_TRUSTSTORE_PASSWORD}" \
    -storetype BCFKS \
    -providername BCFIPS \
    -providerclass org.bouncycastle.jcajce.provider.BouncyCastleFipsProvider \
    -providerpath "${WORK_DIR}/bc-fips.jar" 2>/dev/null | grep -c "trustedCertEntry" || echo "0")

echo "✅ Generated cacerts.bcfks with ${CERT_COUNT} certificates"

# Copy to action directory
cp "${WORK_DIR}/cacerts.bcfks" ./cacerts.bcfks

# Calculate checksum of source JKS for metadata
JKS_SHA256=$(sha256sum "${JRE_DIR}/lib/security/cacerts" | awk '{print $1}')
echo "Source JKS SHA256: ${JKS_SHA256}"

# Output metadata for upload script
{
    echo "CACERTS_CERT_COUNT=${CERT_COUNT}"
    echo "CACERTS_SOURCE_SHA256=${JKS_SHA256}"
    echo "CACERTS_BC_VERSION=${BC_FIPS_VERSION}"
} >> "$GITHUB_ENV"

echo "✅ cacerts.bcfks ready for upload"
