#!/bin/bash

# Configuration
N=${1:-2000} # Default to 1000 if not provided
URL=${2:-"http://parser.external.public.url/api/v1/parser/process"}
CONCURRENT_LIMIT=50 # Control how many processes to spawn at once to avoid OS limits

echo "🚀 Starting Load Test for External Parser"
echo "🎯 Target URL: $URL"
echo "📦 Total Requests: $N"
echo "----------------------------------------"

# Keep track of results
LOG_FILE="test_results.log"
> "$LOG_FILE"

start_time=$(date +%s)

# Function to send a single request
send_request() {
    local id=$1
    # Sending a dummy URL in the body as expected by the ParserController
    response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: text/plain" -d "http://example.com/page_$id" "$URL")
    echo "$response" >> "$LOG_FILE"
}

echo "⌛ Sending requests in parallel..."

# Run requests in parallel with managed concurrency
echo "⌛ Sending requests in parallel..."

for ((i=1; i<=N; i++)); do
    send_request "$i" &
    
    # Check every 100 requests to clear finished processes
    if (( i % 500 == 0 )); then
        wait # Wait for the current batch of 100 to finish before starting the next
        echo "🚀 Batch done... continuing (Total: $i)"
    fi
done

wait # Wait for all remaining jobs

end_time=$(date +%s)
duration=$((end_time - start_time))

# Summary Calculation
total_responses=$(wc -l < "$LOG_FILE")
success_count=$(grep -c "200$" "$LOG_FILE" || true) # Matches status code 200 at the end of response
failure_count=$((total_responses - success_count))

echo "----------------------------------------"
echo "📊 Load Test Results:"
echo "✅ Successes: $success_count"
echo "❌ Failures: $failure_count"
echo "⏱️  Duration: ${duration}s"
if [ $duration -gt 0 ]; then
    echo "⚡ Requests/sec: $((total_responses / duration))"
fi
echo "----------------------------------------"

# Cleanup
rm "$LOG_FILE"
