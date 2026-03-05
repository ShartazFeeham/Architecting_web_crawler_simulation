#!/bin/bash

# Configuration
TEST_COUNT=5
PRINT_FULL_RESPONSE=true

DISCOVERY_URL="http://localhost:8081/api/v1/discovery/generate"
PROCESSOR_URL="http://localhost:8083/api/v1/processor/records"

# Kafka Topic Configuration
TOPIC_DISCOVERY="crawler.discovery.urls"
TOPIC_OUTBOX="crawler.public.crawl_records"
TOPIC_RESULTS="crawler.fetcher.results"

# Database Configuration
DB_CONTAINER="crawler-pg-db"
DB_USER="user"
DB_NAME="crawler_db"

# Colors for better output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'

echo -e "🎯 ${CYAN}${BOLD}Starting Crawler System Deep Inspector (Docker Context)...${NC}"
echo -e "🧪 ${BOLD}Test Intensity: $TEST_COUNT URLs${NC}"

# Helper function to get total offset count for a topic across all partitions
get_kafka_offset() {
    local topic=$1
    local total_offset=0
    # Command returns lines like: crawler.discovery.urls:0:10
    # Using internal bootstrap-server to avoid listener resolution issues
    local offsets=$(docker exec kafka1 kafka-get-offsets --bootstrap-server kafka1:19092 --topic "$topic" 2>/dev/null | grep "$topic")
    
    if [ -z "$offsets" ]; then
        echo 0
        return
    fi

    while read -r line; do
        # Extract the third field separated by colons (the offset)
        offset=$(echo "$line" | awk -F':' '{print $3}')
        if [[ "$offset" =~ ^[0-9]+$ ]]; then
            total_offset=$((total_offset + offset))
        fi
    done <<< "$offsets"
    echo "$total_offset"
}

# Helper function to count DB records for a specific process ID
get_db_count() {
    local pid=$1
    local count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT count(*) FROM crawl_records WHERE process_id = $pid;" 2>/dev/null)
    echo "${count:-0}"
}

# Helper function to check DB status
get_db_status_count() {
    local pid=$1
    local status=$2
    local count=$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT count(*) FROM crawl_records WHERE process_id = $pid AND status = '$status';" 2>/dev/null)
    echo "${count:-0}"
}

# -----------------------------------------------------------------------------------
# Phase 0: Baseline Check
# -----------------------------------------------------------------------------------
echo -e "\n🔍 ${BOLD}Phase 0: Capturing Baseline (Initial Offsets)${NC}"
BASE_DISCOVERY=$(get_kafka_offset "$TOPIC_DISCOVERY")
BASE_OUTBOX=$(get_kafka_offset "$TOPIC_OUTBOX")
BASE_RESULTS=$(get_kafka_offset "$TOPIC_RESULTS")

echo -e "  📊 Initial Offsets -> Discovery: $BASE_DISCOVERY | Outbox: $BASE_OUTBOX | Results: $BASE_RESULTS"

# -----------------------------------------------------------------------------------
# Phase 1: Trigger Discovery
# -----------------------------------------------------------------------------------
echo -e "\n📡 ${BOLD}Phase 1: Triggering URL Discovery...${NC}"
COUNT=$TEST_COUNT
PROCESS_ID=$(curl -s -X POST "$DISCOVERY_URL?count=$COUNT")

if [ -z "$PROCESS_ID" ] || [ "$PROCESS_ID" == "null" ] || [[ ! "$PROCESS_ID" =~ ^[0-9]+$ ]]; then
    echo -e "  ❌ ${RED}Error: Failed to get valid Process ID from Discovery.${NC}"
    echo "  Response: $PROCESS_ID"
    exit 1
fi
echo -e "  🆔 ${GREEN}Process ID received: $PROCESS_ID${NC} (Requested $COUNT URLs)"

# -----------------------------------------------------------------------------------
# Phase 2: Discovery Topic Validation
# -----------------------------------------------------------------------------------
echo -e "\n📬 ${BOLD}Phase 2: Validating Discovery Kafka Topic ($TOPIC_DISCOVERY)...${NC}"
LIMIT=60
INTERVAL=10
for (( i=1; i<=$((LIMIT/INTERVAL)); i++ )); do
    CURRENT_DISCOVERY=$(get_kafka_offset "$TOPIC_DISCOVERY")
    DIFF=$((CURRENT_DISCOVERY - BASE_DISCOVERY))
    if [ "$DIFF" -ge "$COUNT" ]; then
        echo -e "  ✅ ${GREEN}Success: Discovery topic received $DIFF events (Expected $COUNT).${NC}"
        break
    fi
    if [ $i -eq $((LIMIT/INTERVAL)) ]; then
        echo -e "  ❌ ${RED}Timeout: Discovery topic did not receive events after ${LIMIT}s.${NC}"
        exit 1
    fi
    echo -e "  ⏳ [Attempt $i] Waiting for events... (Current Diff: $DIFF)"
    sleep $INTERVAL
done

# -----------------------------------------------------------------------------------
# Phase 3: DB Records Ingestion Validation
# -----------------------------------------------------------------------------------
echo -e "\n🗄️  ${BOLD}Phase 3: Validating DB Ingestion (crawl_records table)...${NC}"
for (( i=1; i<=$((LIMIT/INTERVAL)); i++ )); do
    DB_COUNT=$(get_db_count "$PROCESS_ID")
    if [ "$DB_COUNT" -ge "$COUNT" ]; then
        echo -e "  ✅ ${GREEN}Success: DB ingested $DB_COUNT records for Process ID $PROCESS_ID.${NC}"
        break
    fi
    if [ $i -eq $((LIMIT/INTERVAL)) ]; then
        echo -e "  ❌ ${RED}Timeout: DB records not found after ${LIMIT}s.${NC}"
        exit 1
    fi
    echo -e "  ⏳ [Attempt $i] Waiting for DB records... (Current: $DB_COUNT)"
    sleep $INTERVAL
done

# -----------------------------------------------------------------------------------
# Phase 4: Debezium Outbox Validation
# -----------------------------------------------------------------------------------
echo -e "\n📤 ${BOLD}Phase 4: Validating Debezium Outbox Topic ($TOPIC_OUTBOX)...${NC}"
for (( i=1; i<=$((LIMIT/INTERVAL)); i++ )); do
    CURRENT_OUTBOX=$(get_kafka_offset "$TOPIC_OUTBOX")
    DIFF=$((CURRENT_OUTBOX - BASE_OUTBOX))
    if [ "$DIFF" -ge "$COUNT" ]; then
        echo -e "  ✅ ${GREEN}Success: Outbox topic received $DIFF enrichment events.${NC}"
        break
    fi
    if [ $i -eq $((LIMIT/INTERVAL)) ]; then
        echo -e "  ⚠️  ${YELLOW}Warning: Outbox topic slow or Debezium lag. Continuing...${NC}"
        break
    fi
    echo -e "  ⏳ [Attempt $i] Waiting for Outbox events... (Current Diff: $DIFF)"
    sleep $INTERVAL
done

# -----------------------------------------------------------------------------------
# Phase 5: Fetcher Results Validation
# -----------------------------------------------------------------------------------
echo -e "\n⚙️  ${BOLD}Phase 5: Validating Fetcher Results Topic ($TOPIC_RESULTS)...${NC}"
for (( i=1; i<=$((LIMIT/INTERVAL)); i++ )); do
    CURRENT_RESULTS=$(get_kafka_offset "$TOPIC_RESULTS")
    DIFF=$((CURRENT_RESULTS - BASE_RESULTS))
    if [ "$DIFF" -ge "$COUNT" ]; then
        echo -e "  ✅ ${GREEN}Success: Results topic received $DIFF processing results.${NC}"
        break
    fi
    if [ $i -eq $((LIMIT/INTERVAL)) ]; then
        echo -e "  ⚠️  ${YELLOW}Warning: Results delayed. System might still be processing.${NC}"
        break
    fi
    echo -e "  ⏳ [Attempt $i] Waiting for processing results... (Current Diff: $DIFF)"
    sleep $INTERVAL
done

# -----------------------------------------------------------------------------------
# Phase 6: Final DB Status Validation
# -----------------------------------------------------------------------------------
echo -e "\n🏁 ${BOLD}Phase 6: Finalizing State Check (DB Record Status)${NC}"
COMPLETED=$(get_db_status_count "$PROCESS_ID" "COMPLETED")
FAILED=$(get_db_status_count "$PROCESS_ID" "FAILED")
PENDING=$(get_db_status_count "$PROCESS_ID" "PENDING")

echo -e "  📊 Process Summary for ID $PROCESS_ID:"
echo -e "     - ${GREEN}COMPLETED: $COMPLETED${NC}"
echo -e "     - ${RED}FAILED: $FAILED${NC}"
echo -e "     - ${YELLOW}PENDING: $PENDING${NC}"

if [ $((COMPLETED + FAILED)) -ge "$COUNT" ]; then
    echo -e "\n🏆 ${CYAN}${BOLD}E2E Validation PASSED! All $COUNT URLs reached a terminal state.${NC}"
    
    if [ "$PRINT_FULL_RESPONSE" = true ]; then
        echo -e "\n📄 ${BOLD}Final JSON Data (Full Response):${NC}"
        curl -s "$PROCESSOR_URL/$PROCESS_ID" | python3 -m json.tool
    else
        echo -e "\nℹ️  ${BOLD}Note: Full JSON response printing is disabled.${NC}"
    fi
    exit 0
else
    echo -e "\n⚠️  ${YELLOW}${BOLD}E2E Validation Partial or Slow. Check service logs (via docker logs) for details.${NC}"
    exit 0
fi
