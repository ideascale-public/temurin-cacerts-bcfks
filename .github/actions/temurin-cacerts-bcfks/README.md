# Temurin FIPS Cacerts (BCFKS)

Pre-generated BCFKS format CA certificates for Temurin JRE FIPS builds.

## What Is This?

This package contains `cacerts.bcfks` files - CA certificate trust stores in BouncyCastle FIPS KeyStore (BCFKS) format for use with Temurin JRE FIPS-compliant builds.

## Usage

Download the artifact for your Temurin version:

```bash
# Example: Download cacerts for Temurin 21.0.8+9
crane export ghcr.io/ideascale/temurin-cacerts-bcfks:21.0.8-9 - | tar -xzf - cacerts.bcfks
```

## Available Versions

Artifacts are tagged by Temurin version (e.g., `21.0.8-9` for Temurin `21.0.8+9`).

## Source

Generated from official Temurin JRE releases using BouncyCastle FIPS provider.
Automatically updated daily.

## Usage

### In Workflows

```yaml
- name: Generate FIPS cacerts
  uses: ./.github/actions/temurin-cacerts-bcfks
  with:
    lts: '21'
    mode: 'check-and-generate'
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `lts` | Yes | - | Temurin LTS version (21, 25) |
| `mode` | No | `check-and-generate` | Operation mode: `check-only` or `check-and-generate` |
| `registry` | No | `ghcr.io` | OCI registry host |
| `repository` | No | `ideascale/temurin-cacerts-bcfks` | OCI repository path |
| `github-token` | Yes | - | GitHub token for GHCR authentication |

### Outputs

| Output | Description |
|--------|-------------|
| `artifact-exists` | Whether artifact already exists (`true`/`false`) |
| `artifact-ref` | Full OCI reference (e.g., `ghcr.io/ideascale/temurin-cacerts-bcfks:21.0.8-9`) |
| `temurin-version` | Resolved Temurin version (e.g., `21.0.8+9`) |
| `generated` | Whether a new artifact was generated (`true`/`false`) |

## How It Works

### 1. Resolve Temurin Version
- Queries Adoptium API for latest LTS version
- Example: LTS 21 → `21.0.8+9`

### 2. Check GHCR
- Uses `crane manifest` to check if `cacerts.bcfks` already exists
- Tag format: `ghcr.io/ideascale/temurin-cacerts-bcfks:21.0.8-9`
- No authentication needed (public repository)

### 3. Generate (if not found)
- Downloads specific Temurin JRE version
- Extracts `cacerts` (JKS format)
- Downloads BouncyCastle FIPS 2.1.1 JAR
- Converts JKS → BCFKS using `keytool`
- Outputs `./cacerts.bcfks`

### 4. Upload (if generated)
- Packages as OCI artifact with metadata
- Pushes to GHCR with authentication
- Tags with full version (e.g., `21.0.8-9`)

## Artifact Metadata

Each artifact includes annotations:

```json
{
  "org.opencontainers.image.version": "21.0.8-9",
  "org.opencontainers.image.title": "Temurin 21.0.8+9 FIPS Cacerts (BCFKS)",
  "com.ideascale.temurin.version": "21.0.8+9",
  "com.ideascale.temurin.lts": "21",
  "com.ideascale.bc-fips.version": "2.1.1",
  "com.ideascale.cacerts.count": "139",
  "com.ideascale.source-jks.sha256": "abc123..."
}
```

## Workflow Integration

### Daily Pre-generation

```yaml
# .github/workflows/temurin-cacerts-bcfks.yaml
on:
  schedule:
    - cron: '0 0 * * *'  # Daily at 00:00 UTC
  workflow_dispatch:

jobs:
  generate-cacerts:
    strategy:
      matrix:
        lts: [21, 25]
    steps:
      - uses: ./.github/actions/temurin-cacerts-bcfks
        with:
          lts: ${{ matrix.lts }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### FIPS Build Downloads

```bash
# In convert-cacerts-fips.sh
ARTIFACT_REF="ghcr.io/ideascale/temurin-cacerts-bcfks:${TEMURIN_VERSION_TAG}"

if crane export "$ARTIFACT_REF" - | tar -xzf - cacerts.bcfks; then
  echo "✅ Downloaded pre-built cacerts.bcfks from GHCR"
else
  echo "⚠️  Fallback: Generating locally (non-reproducible)"
  # Original generation logic
fi
```

## One-Time Setup

After first workflow run:

1. Go to: `https://github.com/orgs/IdeaScale/packages/container/temurin-cacerts-bcfks/settings`
2. Under **Danger Zone** → **Change visibility**
3. Select **Public**

This makes artifacts downloadable without authentication.

## Benefits

✅ **Reproducible FIPS builds**: Same Temurin version = same cacerts.bcfks
✅ **Automated**: Daily generation for new versions
✅ **Public artifacts**: No auth needed for downloads
✅ **Versioned**: Tied to specific Temurin releases
✅ **Traceable**: Metadata tracks source and generation details
✅ **Efficient**: Generate once, reuse forever

## Troubleshooting

### Artifact Not Found

Check if the artifact exists:
```bash
crane manifest ghcr.io/ideascale/temurin-cacerts-bcfks:21.0.8-9
```

### Generation Fails

Check the workflow logs for:
- Adoptium API failures
- Download errors
- keytool conversion errors

### Upload Fails

Verify:
- GITHUB_TOKEN has `packages:write` permission
- Repository name is correct
- No rate limiting issues

## Related Documentation

- [Per-Package SOURCE_DATE_EPOCH](../../../.agents/docs/architecture/per-package-source-date-epoch.md)
- [Reproducible Builds Architecture](../../../.agents/docs/architecture/reproducible-builds.md)
