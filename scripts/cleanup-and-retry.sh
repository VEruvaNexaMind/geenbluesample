#!/bin/bash

# Quick cleanup and redeploy script

echo "🧹 Cleaning up resources from bluegreen-demo namespace..."

# Delete resources from the wrong namespace
kubectl delete namespace bluegreen-demo --ignore-not-found=true

echo "✅ Cleanup completed!"
echo ""
echo "🚀 Now run the setup again:"
echo "./scripts/setup.sh setup"
