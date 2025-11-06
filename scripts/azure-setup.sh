#!/bin/bash

###############################################################################
# Azure Setup Script for Spring Boot + DataDog POC
# This script automates the entire Azure deployment process
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

###############################################################################
# Pre-flight Checks
###############################################################################

print_info "Starting pre-flight checks..."

# Check Azure CLI
if ! command_exists az; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check Docker
if ! command_exists docker; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

# Check Maven
if ! command_exists mvn; then
    print_error "Maven is not installed. Please install it first."
    exit 1
fi

print_info "All prerequisites are installed ✓"

###############################################################################
# Configuration
###############################################################################

print_info "Setting up configuration..."

# Prompt for configuration
read -p "Enter Resource Group name [datadog-poc-rg]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-datadog-poc-rg}

read -p "Enter Azure region [centralus]: " LOCATION
LOCATION=${LOCATION:-centralus}

read -p "Enter Container Registry name (must be globally unique) [gunjandatadogpoc]: " ACR_NAME
ACR_NAME=${ACR_NAME:-gunjandatadogpoc}

read -p "Enter App Service name (must be globally unique) [gunjan-springboot-datadog]: " APP_NAME
APP_NAME=${APP_NAME:-gunjan-springboot-datadog}

read -p "Enter App Service Plan name [datadog-poc-plan]: " PLAN_NAME
PLAN_NAME=${PLAN_NAME:-datadog-poc-plan}

read -p "Enter DataDog API Key: " DD_API_KEY
if [ -z "$DD_API_KEY" ]; then
    print_error "DataDog API Key is required!"
    exit 1
fi

read -p "Enter DataDog Site [ap2.datadoghq.com]: " DD_SITE
DD_SITE=${DD_SITE:-ap2.datadoghq.com}

IMAGE_NAME="springboot-datadog-demo"
IMAGE_TAG="v1"

print_info "Configuration complete ✓"

###############################################################################
# Azure Login
###############################################################################

print_info "Checking Azure login status..."
if ! az account show >/dev/null 2>&1; then
    print_info "Logging in to Azure..."
    az login
fi

print_info "Logged in to Azure ✓"

###############################################################################
# Register Providers
###############################################################################

print_info "Registering required Azure providers..."
az provider register --namespace Microsoft.Web --wait
print_info "Providers registered ✓"

###############################################################################
# Create Resource Group
###############################################################################

print_info "Creating resource group: $RESOURCE_GROUP..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

print_info "Resource group created ✓"

###############################################################################
# Create Azure Container Registry
###############################################################################

print_info "Creating Azure Container Registry: $ACR_NAME..."
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku Basic \
  --admin-enabled true \
  --location "$LOCATION" \
  --output none

print_info "Container Registry created ✓"

###############################################################################
# Build and Push Docker Image
###############################################################################

print_info "Building Docker image for AMD64 platform..."
docker buildx build \
  --platform linux/amd64 \
  -t "$IMAGE_NAME:$IMAGE_TAG" \
  .

print_info "Docker image built ✓"

print_info "Logging in to Azure Container Registry..."
az acr login --name "$ACR_NAME"

print_info "Tagging image..."
docker tag "$IMAGE_NAME:$IMAGE_TAG" "$ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG"

print_info "Pushing image to ACR..."
docker push "$ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG"

print_info "Image pushed to ACR ✓"

###############################################################################
# Create App Service Plan
###############################################################################

print_info "Creating App Service Plan: $PLAN_NAME..."
az appservice plan create \
  --name "$PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --is-linux \
  --sku B1 \
  --output none

print_info "App Service Plan created ✓"

###############################################################################
# Create Web App with Docker Container
###############################################################################

print_info "Creating Web App: $APP_NAME..."
az webapp create \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --plan "$PLAN_NAME" \
  --container-image-name "$ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG" \
  --output none

print_info "Web App created ✓"

###############################################################################
# Configure ACR Credentials
###############################################################################

print_info "Configuring ACR credentials..."
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv)

az webapp config container set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --docker-custom-image-name "$ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG" \
  --docker-registry-server-url "https://$ACR_NAME.azurecr.io" \
  --docker-registry-server-user "$ACR_NAME" \
  --docker-registry-server-password "$ACR_PASSWORD" \
  --output none

print_info "ACR credentials configured ✓"

###############################################################################
# Convert to Sidecar Mode
###############################################################################

print_info "Converting to sidecar mode..."
az webapp sitecontainers convert \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --mode sitecontainers \
  --output none

print_info "Converted to sidecar mode ✓"

###############################################################################
# Update Main Container Port
###############################################################################

print_info "Updating main container configuration..."
az webapp sitecontainers update \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --container-name main \
  --target-port 8080 \
  --output none

print_info "Main container configured ✓"

###############################################################################
# Set Environment Variables
###############################################################################

print_info "Setting environment variables..."
az webapp config appsettings set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings \
    LOG_PATH=/home/LogFiles \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=true \
    WEBSITES_PORT=8080 \
    DD_SERVICE=springboot-datadog-demo \
    DD_ENV=poc \
    DD_VERSION=1.0.0 \
  --output none

print_info "Environment variables set ✓"

###############################################################################
# Add DataDog Sidecar Container
###############################################################################

print_info "Adding DataDog sidecar container..."
az webapp sitecontainers create \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --container-name datadog-agent \
  --image datadog/serverless-init:latest \
  --target-port 8126 \
  --is-main false \
  --output none

print_info "DataDog sidecar added ✓"

###############################################################################
# Set DataDog Configuration
###############################################################################

print_info "Setting DataDog configuration..."
az webapp config appsettings set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings \
    DD_API_KEY="$DD_API_KEY" \
    DD_SITE="$DD_SITE" \
    DD_SERVERLESS_LOG_PATH=/home/LogFiles/application.log \
  --output none

print_info "DataDog configuration set ✓"

###############################################################################
# Restart App
###############################################################################

print_info "Restarting application..."
az webapp restart \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --output none

print_info "Application restarted ✓"

###############################################################################
# Get App URL
###############################################################################

APP_URL=$(az webapp show \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "defaultHostName" -o tsv)

###############################################################################
# Summary
###############################################################################

echo ""
echo "========================================="
echo "   DEPLOYMENT COMPLETE! 🎉"
echo "========================================="
echo ""
echo "Application URL: https://$APP_URL"
echo "Resource Group: $RESOURCE_GROUP"
echo "Container Registry: $ACR_NAME.azurecr.io"
echo "App Service: $APP_NAME"
echo ""
echo "Test your endpoints:"
echo "  curl https://$APP_URL/"
echo "  curl https://$APP_URL/health"
echo "  curl https://$APP_URL/api/test"
echo ""
echo "DataDog Dashboard: https://$DD_SITE"
echo ""
echo "Note: It may take 2-5 minutes for data to appear in DataDog"
echo "========================================="
