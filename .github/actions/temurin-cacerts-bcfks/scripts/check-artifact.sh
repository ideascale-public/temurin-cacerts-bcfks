#!/usr/bin/env bash
# Check if cacerts.bcfks artifact exists in GHCR
#
# Usage: check-artifact.sh <artifact-ref>
#   artifact-ref: Full OCI reference (e.g., ghcr.io/ideascale/temurin-cacerts-bcfks:21.0.8-9)
#
# Returns:
#   0 if artifact exists
#   1 if artifact not found

set -euo pipefail

ARTIFACT_REF="${1:?Artifact reference required}"

echo "Checking if artifact exists: ${ARTIFACT_REF}"

# Use crane to check if manifest exists (no auth needed for public repos)
if crane manifest "$ARTIFACT_REF" >/dev/null 2>&1; then
    echo "✅ Artifact exists"
    exit 0
else
    echo "⚠️  Artifact not found"
    exit 1
fi
