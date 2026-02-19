#!/bin/bash

# Define endpoints
DISCOVERY_URL="http://localhost:8081/api/v1/discovery/generate"
PROCESSOR_URL="http://localhost:8083/api/v1/processor/records"

echo "🎯 Starting Test Runner..."

# 1. Trigger Discovery
echo "📡 Triggering URL Discovery..."
PROCESS_ID=$(curl -s -X POST "$DISCOVERY_URL" -H "Content-Type: application/json" -d '{"count": 10}')

if [ -z "$PROCESS_ID" ] || [ "$PROCESS_ID" == "null" ]; then
    echo "❌ Error: Failed to get Process ID."
    exit 1
fi

echo "🆔 Process ID received: $PROCESS_ID"

# 2. Wait for processing (Jitter wait)
echo "⏳ Waiting 10 seconds for completion..."
sleep 10

# 3. Retrieve Results
echo "🔍 Querying Processor for results..."
RESULTS=$(curl -s -X GET "$PROCESSOR_URL/$PROCESS_ID")

if [ "$RESULTS" == "[]" ] || [ -z "$RESULTS" ]; then
    echo "⚠️  No records found yet for ID $PROCESS_ID. System might still be processing."
else
    echo "🏆 Results received:"
    echo "$RESULTS" | python3 -m json.tool
fi

echo "🏁 Test completed."
