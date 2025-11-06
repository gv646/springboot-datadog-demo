#!/bin/bash

###############################################################################
# Cleanup Script for Azure Resources
# WARNING: This will delete ALL resources in the resource group
###############################################################################

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}WARNING: This will delete all Azure resources!${NC}"
read -p "Enter Resource Group name to delete [datadog-poc-rg]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-datadog-poc-rg}

echo ""
echo "This will delete:"
echo "  - Resource Group: $RESOURCE_GROUP"
echo "  - All resources within it (App Service, ACR, etc.)"
echo ""
read -p "Are you sure? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo "Deleting resource group: $RESOURCE_GROUP..."
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

echo ""
echo "========================================="
echo "  Cleanup initiated!"
echo "========================================="
echo ""
echo "The resource group is being deleted in the background."
echo "This may take 5-10 minutes to complete."
echo ""
echo "Check status with:"
echo "  az group show --name $RESOURCE_GROUP"
echo "========================================="
