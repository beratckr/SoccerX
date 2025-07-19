#!/bin/bash

# SoccerX Project Folder Structure Setup
# Run this from /Users/furkan/SoccerX directory

echo "🚀 Creating SoccerX folder structure..."

# Create iOS directories
echo "📱 Creating iOS folders..."
mkdir -p iOS/SoccerX/App
mkdir -p iOS/SoccerX/Models
mkdir -p iOS/SoccerX/ViewModels
mkdir -p iOS/SoccerX/Views/Onboarding
mkdir -p iOS/SoccerX/Views/Dashboard
mkdir -p iOS/SoccerX/Views/GameTracking
mkdir -p iOS/SoccerX/Views/History
mkdir -p iOS/SoccerX/Views/Groups
mkdir -p iOS/SoccerX/Views/Profile
mkdir -p iOS/SoccerX/Views/Premium
mkdir -p iOS/SoccerX/Views/Components
mkdir -p iOS/SoccerX/Services
mkdir -p iOS/SoccerX/Utils/Extensions
mkdir -p iOS/SoccerX/Resources/Assets.xcassets
mkdir -p iOS/SoccerX/Resources/Fonts

# Create watchOS directories
echo "⌚ Creating watchOS folders..."
mkdir -p iOS/SoccerXWatch/Views/Home
mkdir -p iOS/SoccerXWatch/Views/Tracking
mkdir -p iOS/SoccerXWatch/Views/Details
mkdir -p iOS/SoccerXWatch/Services
mkdir -p iOS/SoccerXWatch/Models

# Create Shared directories
echo "🔗 Creating shared folders..."
mkdir -p iOS/Shared/Models
mkdir -p iOS/Shared/Utilities
mkdir -p iOS/Shared/Extensions

# Create Backend directories
echo "☁️  Creating backend folders..."
mkdir -p Backend/functions/src/triggers
mkdir -p Backend/functions/src/services
mkdir -p Backend/functions/src/utils
mkdir -p Backend/functions/src/types
mkdir -p Backend/functions/tests
mkdir -p Backend/scripts

# Create Config directories
echo "⚙️  Creating config folders..."
mkdir -p Config/Development
mkdir -p Config/Production

# Create Scripts directory
echo "📝 Creating scripts folder..."
mkdir -p Scripts

# Create Documentation directory
echo "📚 Creating documentation folders..."
mkdir -p Documentation/API
mkdir -p Documentation/Architecture
mkdir -p Documentation/Guides

echo "✅ Folder structure created successfully!"
