#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Shelf Elf — Netlify deploy script
# Deploys the docs/ folder (share redirect page) to Netlify
#
# Requirements:
#   npm install -g netlify-cli     (one-time install)
#   netlify login                  (one-time login)
#
# Usage:
#   chmod +x deploy_netlify.sh
#   ./deploy_netlify.sh
#
# On first run it will create a new Netlify site and save the site ID.
# Subsequent runs deploy to the same site.
# ─────────────────────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$SCRIPT_DIR/docs"
CONFIG_FILE="$SCRIPT_DIR/.netlify_site_id"

# ── Check netlify CLI is installed ────────────────────────────────────────────
if ! command -v netlify &> /dev/null; then
    echo ""
    echo "  netlify-cli is not installed."
    echo "  Run: npm install -g netlify-cli"
    echo "  Then: netlify login"
    echo ""
    exit 1
fi

# ── Check docs/ folder exists ─────────────────────────────────────────────────
if [ ! -d "$DEPLOY_DIR" ]; then
    echo "Error: docs/ folder not found at $DEPLOY_DIR"
    exit 1
fi

echo ""
echo "🧝 Shelf Elf — Netlify Deploy"
echo "──────────────────────────────"

# ── First time: create site and save ID ──────────────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
    echo "No site ID found. Creating new Netlify site..."
    echo ""

    SITE_OUTPUT=$(netlify sites:create \
        --name "shelf-elf-share" \
        --account-slug "" \
        2>&1)

    SITE_ID=$(echo "$SITE_OUTPUT" | grep -oP 'Site ID:\s*\K\S+' || true)

    if [ -z "$SITE_ID" ]; then
        # Try alternative output format
        SITE_ID=$(echo "$SITE_OUTPUT" | grep -oP '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' | head -1 || true)
    fi

    if [ -z "$SITE_ID" ]; then
        echo "Could not extract site ID automatically."
        echo "Run 'netlify sites:list' and paste your site ID:"
        read -r SITE_ID
    fi

    echo "$SITE_ID" > "$CONFIG_FILE"
    echo "Site ID saved to .netlify_site_id"
fi

SITE_ID=$(cat "$CONFIG_FILE")
echo "Site ID: $SITE_ID"
echo ""

# ── Deploy ────────────────────────────────────────────────────────────────────
echo "Deploying docs/ to Netlify..."
echo ""

netlify deploy \
    --dir="$DEPLOY_DIR" \
    --site="$SITE_ID" \
    --prod \
    --message="Shelf Elf share page deploy"

echo ""
echo "✅ Deploy complete!"
echo ""
echo "Your share redirect page is live."
echo "Update the URL in lib/services/share_service.dart if needed."
echo ""
