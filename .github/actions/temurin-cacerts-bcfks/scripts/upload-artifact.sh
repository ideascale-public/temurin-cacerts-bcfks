#!/usr/bin/env bash
# Upload cacerts.bcfks to GHCR as OCI artifact
#
# Usage: upload-artifact.sh <artifact-ref> <version> <version-tag>
#   artifact-ref: Full OCI reference (e.g., ghcr.io/ideascale/temurin-cacerts-bcfks:21.0.8-9)
#   version: Full Temurin version (e.g., 21.0.8+9)
#   version-tag: Version with - instead of + (e.g., 21.0.8-9)
#
# Environment variables:
#   GITHUB_TOKEN: GitHub token for authentication
#   CACERTS_CERT_COUNT: Number of certificates (from generate script)
#   CACERTS_SOURCE_SHA256: SHA256 of source JKS (from generate script)
#   CACERTS_BC_VERSION: BouncyCastle version (from generate script)

set -euo pipefail

ARTIFACT_REF="${1:?Artifact reference required}"
VERSION="${2:?Version required}"
VERSION_TAG="${3:?Version tag required}"

if [[ ! -f "./cacerts.bcfks" ]]; then
    echo "cacerts.bcfks not found in current directory"
    exit 1
fi

echo "Uploading cacerts.bcfks to ${ARTIFACT_REF}"

# Login to registry
REGISTRY="${ARTIFACT_REF%%/*}"
echo "${GITHUB_TOKEN}" | crane auth login "$REGISTRY" -u "${GITHUB_ACTOR:-github-actions}" --password-stdin

# Create a tar.gz archive with the cacerts.bcfks file
TEMP_TAR=$(mktemp --suffix=.tar.gz)
trap 'rm -f "$TEMP_TAR"' EXIT

tar -czf "$TEMP_TAR" cacerts.bcfks

# Use crane append with busybox:latest as base
# Then we'll extract just our layer, but this is the simplest approach that works
crane append \
    --base busybox:latest \
    --new_layer "$TEMP_TAR" \
    --new_tag "$ARTIFACT_REF"

if [[ $? -ne 0 ]]; then
    echo "Failed to upload artifact"
    exit 1
fi

echo "✅ Uploaded successfully: ${ARTIFACT_REF}"
echo "   Certificates: ${CACERTS_CERT_COUNT:-unknown}"
echo "   BC FIPS Version: ${CACERTS_BC_VERSION:-unknown}"
echo "   Source JKS SHA256: ${CACERTS_SOURCE_SHA256:-unknown}"
echo ""
echo "Note: Image contains busybox base layers + cacerts.bcfks layer"
echo "Extract with: crane export ${ARTIFACT_REF} - | tar -xzf - cacerts.bcfks"

