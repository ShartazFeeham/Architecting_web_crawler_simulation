#!/bin/bash

# ==============================================================================
# K8s Management and Test Console
# Environment Configurations
# ==============================================================================
# Detect project root (directory where k8s/ is located)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

DISCOVERY_HOST="discovery.crawler.public.url"
PROCESSOR_HOST="processor.crawler.public.url"
KAFKADROP_HOST="kafka.crawler.public.url"
PARSER_HOST="parser.external.public.url"
NGINX_BASE="http://localhost"

# Namespaces
INFRA_NS="crawler-infrastructure"
APPS_NS="crawler-apps"
EXT_NS="crawler-external"

# Release Names
INFRA_RELEASE="infra-test"
APPS_RELEASE="crawler-apps"
EXT_RELEASE="parser-external"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ==============================================================================
# Helper Functions
# ==============================================================================
print_header() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "   ${YELLOW}K8s Management & Test Console${NC}"
    echo -e "${BLUE}=======================================${NC}"
}

run_cmd() {
    local cmd=$1
    local detach=$2
    
    if [[ "$detach" == "true" ]]; then
        echo -e "${BLUE}Running in background: ${NC}$cmd"
        nohup bash -c "$cmd" > /dev/null 2>&1 &
        echo -e "${GREEN}Process ID: $!${NC}"
    else
        echo -e "${BLUE}Executing: ${NC}$cmd"
        eval "$cmd"
    fi
}

# ==============================================================================
# Core Operations
# ==============================================================================
helm_op() {
    local op_type=$1 # upgrade or uninstall
    
    echo -e "\n${YELLOW}--- Helm $op_type Mode ---${NC}"
    echo "1. Wait (Synchronous)"
    echo "2. Detach (Background)"
    echo -ne "${BLUE}Choose mode: ${NC}"
    read mode_choice
    
    local detach="false"
    if [[ "$mode_choice" == "2" ]]; then detach="true"; fi

    local wait_flag=""
    if [[ "$op_type" == "upgrade" && "$detach" == "false" ]]; then
        wait_flag="--wait"
    fi

    echo -e "\n${YELLOW}--- Helm $op_type Options ($([[ "$detach" == "true" ]] && echo "Detach" || echo "Wait")) ---${NC}"
    
    if [[ "$op_type" == "upgrade" ]]; then
        echo "1. Infrastructure  (helm upgrade --install $INFRA_RELEASE $PROJECT_ROOT/k8s/helm/infra $wait_flag -n $INFRA_NS)"
        echo "2. Crawler Apps    (helm upgrade --install $APPS_RELEASE $PROJECT_ROOT/k8s/helm/apps $wait_flag -n $APPS_NS)"
        echo "3. External Sim    (helm upgrade --install $EXT_RELEASE $PROJECT_ROOT/k8s/helm/external $wait_flag -n $EXT_NS)"
    else
        echo "1. Infrastructure  (helm uninstall $INFRA_RELEASE -n $INFRA_NS)"
        echo "2. Crawler Apps    (helm uninstall $APPS_RELEASE -n $APPS_NS)"
        echo "3. External Sim    (helm uninstall $EXT_RELEASE -n $EXT_NS)"
    fi
    echo "4. All Together"
    echo "5. Back to Main Menu"
    echo -ne "${BLUE}Choose an option: ${NC}"
    read choice

    local cmd=""
    case $choice in
        1) 
            if [[ "$op_type" == "upgrade" ]]; then
                cmd="helm upgrade --install $INFRA_RELEASE $PROJECT_ROOT/k8s/helm/infra $wait_flag -n $INFRA_NS"
            else
                cmd="helm uninstall $INFRA_RELEASE -n $INFRA_NS"
            fi
            ;;
        2) 
            if [[ "$op_type" == "upgrade" ]]; then
                cmd="helm upgrade --install $APPS_RELEASE $PROJECT_ROOT/k8s/helm/apps $wait_flag -n $APPS_NS"
            else
                cmd="helm uninstall $APPS_RELEASE -n $APPS_NS"
            fi
            ;;
        3) 
            if [[ "$op_type" == "upgrade" ]]; then
                cmd="helm upgrade --install $EXT_RELEASE $PROJECT_ROOT/k8s/helm/external $wait_flag -n $EXT_NS"
            else
                cmd="helm uninstall $EXT_RELEASE -n $EXT_NS"
            fi
            ;;
        4) 
            if [[ "$op_type" == "upgrade" ]]; then
                cmd="helm upgrade --install $INFRA_RELEASE $PROJECT_ROOT/k8s/helm/infra $wait_flag -n $INFRA_NS && \
                     helm upgrade --install $APPS_RELEASE $PROJECT_ROOT/k8s/helm/apps $wait_flag -n $APPS_NS && \
                     helm upgrade --install $EXT_RELEASE $PROJECT_ROOT/k8s/helm/external $wait_flag -n $EXT_NS"
            else
                cmd="helm uninstall $APPS_RELEASE -n $APPS_NS; \
                     helm uninstall $EXT_RELEASE -n $EXT_NS; \
                     helm uninstall $INFRA_RELEASE -n $INFRA_NS"
            fi
            ;;
        5) return ;;
        *) echo -e "${RED}Invalid option${NC}"; return ;;
    esac

    run_cmd "$cmd" "$detach"
}

run_k8s_test() {
    echo -e "\n${YELLOW}--- Running K8s Pipeline Test (via Ingress) ---${NC}"
    echo "1. Wait (Synchronous)"
    echo "2. Detach (Background)"
    echo -ne "${BLUE}Choose mode: ${NC}"
    read mode_choice
    
    local detach="false"
    if [[ "$mode_choice" == "2" ]]; then detach="true"; fi

    echo -ne "Enter number of URLs to generate: "
    read count
    if [[ -z "$count" ]]; then count=5; fi

    local test_script="
    echo 'Step 1: Hitting Discovery Service -> http://$DISCOVERY_HOST'
    curl -s -X POST '$NGINX_BASE/api/v1/discovery/generate?count=$count' -H 'Host: $DISCOVERY_HOST'
    echo -e '\nWaiting 15 seconds for pipeline propagation...'
    sleep 15
    echo 'Step 2: Checking Processor Stats -> http://$PROCESSOR_HOST'
    curl -s '$NGINX_BASE/api/v1/processor/stats' -H 'Host: $PROCESSOR_HOST' | python3 -m json.tool
    "

    if [[ "$detach" == "true" ]]; then
        run_cmd "$test_script" "true"
    else
        eval "$test_script"
    fi
}

deep_clean() {
    echo -e "\n${RED}--- WARNING: DEEP CLEAN ---${NC}"
    echo -e "${YELLOW}This will uninstall all releases and DELETE all data (PVCs).${NC}"
    echo -ne "Are you sure? (y/n): "
    read confirm
    if [[ "$confirm" != "y" ]]; then return; fi

    echo -e "${RED}Uninstalling all releases...${NC}"
    helm uninstall $APPS_RELEASE -n $APPS_NS > /dev/null 2>&1
    helm uninstall $EXT_RELEASE -n $EXT_NS > /dev/null 2>&1
    helm uninstall $INFRA_RELEASE -n $INFRA_NS > /dev/null 2>&1

    echo -e "${YELLOW}Waiting 10s for releases to detach...${NC}"
    sleep 10

    echo -e "${RED}Deleting all PVCs in $INFRA_NS, $APPS_NS, $EXT_NS...${NC}"
    kubectl delete pvc --all -n $INFRA_NS
    kubectl delete pvc --all -n $APPS_NS
    kubectl delete pvc --all -n $EXT_NS

    echo -e "${GREEN}Deep clean complete.${NC}"
}

show_status() {
    echo -e "\n${YELLOW}--- Cluster Status ---${NC}"
    echo -e "${BLUE}Pods:${NC}"
    kubectl get pods -A | grep -E "NAMESPACE|crawler|parser"
    echo -e "\n${BLUE}Ingress:${NC}"
    kubectl get ing -A | grep -E "NAMESPACE|crawler|parser"
    echo -e "\n${BLUE}HPA (Autoscalers):${NC}"
    kubectl get hpa -A | grep -E "NAMESPACE|crawler|parser" || echo "No HPAs found."
}

show_stats() {
    echo -e "\n${YELLOW}--- Pipeline Stats (Processor) ---${NC}"
    curl -s "$NGINX_BASE/api/v1/processor/stats" -H "Host: $PROCESSOR_HOST" | python3 -m json.tool || echo -e "${RED}Stats endpoint unreachable${NC}"
}

# ==============================================================================
# Main Loop
# ==============================================================================
while true; do
    print_header
    echo "1. Helm Upgrade"
    echo "2. Delete Helm Deployment"
    echo "3. Run K8s Test (E2E)"
    echo "4. Show Cluster Status (Inc. HPA)"
    echo "5. Show Pipeline Stats (Processor) [DEFAULT]"
    echo "6. Deep Clean (Uninstall + Delete All Data)"
    echo "7. Open KafkaDrop (Host Info Only)"
    echo "8. Exit"
    echo -ne "${BLUE}Select an option (Default 5): ${NC}"
    read main_choice
    
    if [[ -z "$main_choice" ]]; then main_choice="5"; fi

    case $main_choice in
        1) helm_op "upgrade" ;;
        2) helm_op "uninstall" ;;
        3) run_k8s_test ;;
        4) show_status ;;
        5) show_stats ;;
        6) deep_clean ;;
        7) echo -e "${GREEN}KafkaDrop URL: http://$KAFKADROP_HOST (via Ingress)${NC}" ;;
        8) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    echo ""
done
