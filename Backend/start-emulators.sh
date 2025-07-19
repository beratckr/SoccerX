#!/bin/bash

# Start Firebase emulators with demo project
echo "Starting Firebase emulators..."
firebase emulators:start --only functions,firestore --project demo-soccerx

# Note: To run in background, use:
# firebase emulators:start --only functions,firestore --project demo-soccerx &

# To stop emulators running in background:
# lsof -ti:5001,8080,4000 | xargs kill -9