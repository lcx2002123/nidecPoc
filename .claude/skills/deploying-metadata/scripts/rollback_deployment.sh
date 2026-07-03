#!/bin/bash
# Rollback Salesforce deployment to previous snapshot
#
# Requirements:
#   - Salesforce CLI (sf) v2.x+ installed
#   - Authenticated Salesforce org via: sf org login web -a <org-alias>
#   - Valid snapshot directory (created by snapshot_org.sh)
#   - Write permissions for creating pre-rollback backup
#
# Safety: ⚠️ DESTRUCTIVE - DEPLOYS CODE
#   This script DEPLOYS CODE to the target org.
#   Requires explicit confirmation with "yes".
#   Creates a pre-rollback backup before proceeding.
#
# Usage:
#   ./rollback_deployment.sh production ./backups/prod-2025-10-19
#   ./rollback_deployment.sh sandbox ./backups/sandbox-last-good
#
# ⚠️ WARNING:
#   This will deploy the snapshot, potentially overwriting current metadata.
#   A pre-rollback backup will be created for safety.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ $# -lt 2 ]; then
    echo "Usage: rollback_deployment.sh <org-alias> <snapshot-directory>"
    echo ""
    echo "Rolls back org to a previous snapshot."
    echo ""
    echo "Examples:"
    echo "  rollback_deployment.sh production ./backups/prod-2025-10-19"
    echo "  rollback_deployment.sh sandbox ./backups/sandbox-last-good"
    echo ""
    exit 1
fi

ORG_ALIAS=$1
SNAPSHOT_DIR=$2

echo -e "${RED}⚠️  ROLLBACK DEPLOYMENT${NC}"
echo "======================================================================"
echo "Org: $ORG_ALIAS"
echo "Snapshot: $SNAPSHOT_DIR"
echo "======================================================================"

# Verify snapshot exists
if [ ! -d "$SNAPSHOT_DIR" ]; then
    echo -e "${RED}Error: Snapshot directory not found: $SNAPSHOT_DIR${NC}"
    exit 1
fi

if [ ! -d "$SNAPSHOT_DIR/src" ]; then
    echo -e "${RED}Error: No src/ directory in snapshot${NC}"
    exit 1
fi

# Show snapshot info if available
if [ -f "$SNAPSHOT_DIR/snapshot-info.json" ]; then
    echo -e "\n${BLUE}Snapshot Information:${NC}"
    cat "$SNAPSHOT_DIR/snapshot-info.json"
    echo ""
fi

# Confirmation prompt
echo -e "${YELLOW}⚠️  WARNING: This will deploy the snapshot to $ORG_ALIAS${NC}"
echo -e "${YELLOW}This may overwrite current metadata!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Rollback cancelled."
    exit 0
fi

# Create pre-rollback snapshot
PREROLLBACK_DIR="./prerollback-$(date +%Y-%m-%d_%H-%M-%S)"
echo -e "\n${YELLOW}Creating pre-rollback snapshot...${NC}"
echo "Location: $PREROLLBACK_DIR"

mkdir -p "$PREROLLBACK_DIR"
sf project retrieve start \
  -x "$SNAPSHOT_DIR/package.xml" \
  -o "$ORG_ALIAS" \
  -d "$PREROLLBACK_DIR/src" \
  --wait 10 || true

# Deploy snapshot
echo -e "\n${BLUE}Deploying snapshot to $ORG_ALIAS...${NC}"

sf project deploy start \
  -d "$SNAPSHOT_DIR/src" \
  -o "$ORG_ALIAS" \
  --test-level RunLocalTests \
  --wait 30

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ Rollback Successful!${NC}"
    echo "======================================================================"
    echo "Org: $ORG_ALIAS"
    echo "Rolled back to: $SNAPSHOT_DIR"
    echo "Pre-rollback backup: $PREROLLBACK_DIR"
    echo "======================================================================"
    echo ""
    echo "💡 Next Steps:"
    echo "   1. Verify critical functionality"
    echo "   2. Run smoke tests"
    echo "   3. Monitor for issues"
    echo "   4. Communicate rollback to stakeholders"
    echo ""
else
    echo -e "\n${RED}❌ Rollback Failed!${NC}"
    echo "======================================================================"
    echo "Check the error messages above."
    echo "Pre-rollback backup available at: $PREROLLBACK_DIR"
    echo ""
    echo "To retry manually:"
    echo "  sf project deploy start -d $SNAPSHOT_DIR/src -o $ORG_ALIAS"
    echo "======================================================================"
    exit 1
fi
