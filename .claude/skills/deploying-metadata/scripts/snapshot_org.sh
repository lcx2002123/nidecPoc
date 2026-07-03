#!/bin/bash
# Create a metadata snapshot of Salesforce org before deployment
# Useful for rollback and disaster recovery
#
# Requirements:
#   - Salesforce CLI (sf) v2.x+ installed
#   - Authenticated Salesforce org via: sf org login web -a <org-alias>
#   - Write permissions for output directory
#   - git command available (optional, for commit hash)
#
# Safety: READ-ONLY (with local file creation)
#   This script only reads metadata from org and saves locally.
#   No changes are made to the org.
#
# Usage:
#   ./snapshot_org.sh production ./backups/prod-2025-10-20
#   ./snapshot_org.sh sandbox ./backups/sandbox-$(date +%Y-%m-%d)
#
# Output:
#   - package.xml: Metadata manifest
#   - src/: All retrieved metadata
#   - snapshot-info.json: Snapshot metadata (timestamp, git commit, etc)

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ $# -lt 2 ]; then
    echo "Usage: snapshot_org.sh <org-alias> <output-directory>"
    echo ""
    echo "Creates a metadata snapshot for rollback purposes."
    echo ""
    echo "Examples:"
    echo "  snapshot_org.sh production ./backups/prod-2025-10-20"
    echo "  snapshot_org.sh sandbox ./backups/sandbox-$(date +%Y-%m-%d)"
    echo ""
    exit 1
fi

ORG_ALIAS=$1
OUTPUT_DIR=$2

echo -e "${BLUE}📸 Creating Org Snapshot${NC}"
echo "======================================================================"
echo "Org: $ORG_ALIAS"
echo "Output: $OUTPUT_DIR"
echo "======================================================================"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get Git commit hash if in repo
GIT_COMMIT=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "not-in-git")
fi

# Create manifest file with all metadata
echo -e "\n${YELLOW}Creating manifest...${NC}"
cat > "$OUTPUT_DIR/package.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types><members>*</members><name>ApexClass</name></types>
    <types><members>*</members><name>ApexTrigger</name></types>
    <types><members>*</members><name>ApexPage</name></types>
    <types><members>*</members><name>ApexComponent</name></types>
    <types><members>*</members><name>LightningComponentBundle</name></types>
    <types><members>*</members><name>AuraDefinitionBundle</name></types>
    <types><members>*</members><name>CustomObject</name></types>
    <types><members>*</members><name>CustomField</name></types>
    <types><members>*</members><name>ValidationRule</name></types>
    <types><members>*</members><name>WorkflowRule</name></types>
    <types><members>*</members><name>Flow</name></types>
    <version>64.0</version>
</Package>
EOF

# Retrieve metadata
echo -e "\n${YELLOW}Retrieving metadata...${NC}"
sf project retrieve start \
  -x "$OUTPUT_DIR/package.xml" \
  -o "$ORG_ALIAS" \
  -d "$OUTPUT_DIR/src" \
  --wait 10

# Create snapshot metadata file
echo -e "\n${YELLOW}Creating snapshot metadata...${NC}"
cat > "$OUTPUT_DIR/snapshot-info.json" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "org_alias": "$ORG_ALIAS",
  "git_commit": "$GIT_COMMIT",
  "created_by": "$(whoami)",
  "purpose": "Pre-deployment backup"
}
EOF

echo -e "\n${GREEN}✅ Snapshot Created Successfully!${NC}"
echo "======================================================================"
echo "Location: $OUTPUT_DIR"
echo "Timestamp: $(date)"
if [ -n "$GIT_COMMIT" ]; then
    echo "Git Commit: $GIT_COMMIT"
fi
echo "======================================================================"
echo ""
echo "💡 To rollback to this snapshot:"
echo "   ./scripts/rollback_deployment.sh $ORG_ALIAS $OUTPUT_DIR"
echo ""
