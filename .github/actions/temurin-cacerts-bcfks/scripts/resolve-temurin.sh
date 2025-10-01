#!/usr/bin/env bash
# Resolve Temurin version for given LTS using Adoptium API
#
# Usage: resolve-temurin.sh <lts> <registry> <repository>
#   lts: Temurin LTS major version (21, 25)
#   registry: OCI registry (e.g., ghcr.io)
#   repository: OCI repository path (e.g., ideascale/temurin-cacerts-bcfks)
#
# Outputs (to GITHUB_OUTPUT):
#   version: Full version with + (e.g., 21.0.8+9)
#   version-tag: Version with - instead of + (e.g., 21.0.8-9)
#   artifact-ref: Full OCI reference

set -euo pipefail

LTS="${1:?LTS version required}"
REGISTRY="${2:?Registry required}"
REPOSITORY="${3:?Repository required}"

# Determine architecture
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) ADOPTIUM_ARCH="x64" ;;
    aarch64|arm64) ADOPTIUM_ARCH="aarch64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "Resolving Temurin ${LTS} for ${ADOPTIUM_ARCH}..."

# Fetch from Adoptium API
API_URL="https://api.adoptium.net/v3/assets/latest/${LTS}/hotspot?image_type=jre&os=linux&architecture=${ADOPTIUM_ARCH}"

if ! RESPONSE=$(curl -fsSL --retry 3 --retry-delay 2 "$API_URL" 2>/dev/null); then
    echo "Failed to fetch Temurin metadata from Adoptium API"
    exit 1
fi

# Extract download URL and version components
DOWNLOAD_URL=$(echo "$RESPONSE" | jq -r '.[0].binary.package.link // empty')
MAJOR=$(echo "$RESPONSE" | jq -r '.[0].version.major // empty')
MINOR=$(echo "$RESPONSE" | jq -r '.[0].version.minor // empty')
SECURITY=$(echo "$RESPONSE" | jq -r '.[0].version.security // empty')
BUILD=$(echo "$RESPONSE" | jq -r '.[0].version.build // empty')

if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
    echo "Failed to get download URL from Adoptium API"
    exit 1
fi

if [[ -z "$MAJOR" || -z "$MINOR" || -z "$SECURITY" || -z "$BUILD" ]]; then
    echo "Failed to get version components from Adoptium API"
    exit 1
fi

# Construct clean version: major.minor.security+build (e.g., 21.0.8+9, 25.0.0+36)
VERSION="${MAJOR}.${MINOR}.${SECURITY}+${BUILD}"

# Convert + to - for tagging (21.0.8+9 → 21.0.8-9, 25.0.0+36 → 25.0.0-36)
VERSION_TAG="${VERSION//+/-}"

# Build artifact reference
ARTIFACT_REF="${REGISTRY}/${REPOSITORY}:${VERSION_TAG}"

echo "✅ Resolved Temurin ${VERSION} (LTS ${LTS})"
echo "   Artifact: ${ARTIFACT_REF}"

# Output to GitHub Actions
{
    echo "version=${VERSION}"
    echo "version-tag=${VERSION_TAG}"
    echo "artifact-ref=${ARTIFACT_REF}"
    echo "download-url=${DOWNLOAD_URL}"
} >> "$GITHUB_OUTPUT"
