#!/bin/bash
# Build script for IPMI sidecar Docker image
# Usage: ./build.sh [registry]
# Example: ./build.sh ghcr.io/bancey

set -e

REGISTRY="${1:-bancey}"
IMAGE_NAME="ipmi-sidecar"
TAG="${2:-latest}"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "Building IPMI sidecar Docker image..."
echo "Image: ${FULL_IMAGE}"

# Change to the script directory
cd "$(dirname "$0")"

# Build the image
docker build -t "${FULL_IMAGE}" .

echo "Build successful!"
echo ""
echo "To push the image to your registry, run:"
echo "  docker push ${FULL_IMAGE}"
echo ""
echo "To test the image locally, run:"
echo "  docker run -p 8080:8080 -e API_KEY=test-key -e BMC_HOST=192.168.1.100 -e BMC_USER=ADMIN -e BMC_PASSWORD=ADMIN ${FULL_IMAGE}"
echo ""
echo "Don't forget to update the image repository in kubernetes/apps/base/home-assistant/release.yaml:"
echo "  ipmi-sidecar:"
echo "    image:"
echo "      repository: ${REGISTRY}/${IMAGE_NAME}"
echo "      tag: ${TAG}"
