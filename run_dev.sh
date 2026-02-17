#!/bin/bash
# Flutter Order App - Development Server (Port 63544)
# This script ensures the app always runs on port 63544

echo "🚀 Starting Flutter Order App on http://localhost:63544"
echo ""

flutter run -d chrome --web-port=63544
