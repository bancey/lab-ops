#!/bin/bash
# Test script for IPMI sidecar API
# This script tests all API endpoints locally

set -e

API_URL="${1:-http://localhost:8080}"
API_KEY="${2:-test-key}"

echo "Testing IPMI Sidecar API at ${API_URL}"
echo "Using API Key: ${API_KEY}"
echo ""

# Test health endpoint (no auth required)
echo "1. Testing health endpoint..."
curl -s "${API_URL}/health" | python3 -m json.tool
echo ""

# Test power status
echo "2. Testing power status..."
curl -s -H "X-API-Key: ${API_KEY}" "${API_URL}/power/status" | python3 -m json.tool
echo ""

# Test invalid API key
echo "3. Testing invalid API key (should fail)..."
curl -s -H "X-API-Key: wrong-key" "${API_URL}/power/status" | python3 -m json.tool
echo ""

# Note: Uncomment these to test actual power commands (use with caution!)
# echo "4. Testing power on..."
# curl -s -X POST -H "X-API-Key: ${API_KEY}" "${API_URL}/power/on" | python3 -m json.tool
# echo ""

# echo "5. Testing power off..."
# curl -s -X POST -H "X-API-Key: ${API_KEY}" "${API_URL}/power/off" | python3 -m json.tool
# echo ""

echo "Basic API tests completed!"
echo ""
echo "To test other endpoints, uncomment the sections in this script and run again."
echo "WARNING: Only test power commands against servers you control!"
