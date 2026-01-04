#!/bin/bash

# Formal verification script for buggy OR1200 using SymbiYosys
# This script runs formal verification tasks on the OR1200 processor design

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESIGN_DIR="${SCRIPT_DIR}"
SBY_FILE="or1200_formal.sby"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}OR1200 Buggy Design Formal Verification${NC}"
echo "========================================"
echo "Design directory: $DESIGN_DIR"
echo "SBY config file: $SBY_FILE"
echo ""

# Check if SymbiYosys is installed
if ! command -v sby &> /dev/null; then
    echo -e "${RED}Error: SymbiYosys (sby) is not installed or not in PATH${NC}"
    echo "Please install SymbiYosys from: https://github.com/YosysHQ/sby"
    exit 1
fi

# Check if Yosys is installed
if ! command -v yosys &> /dev/null; then
    echo -e "${RED}Error: Yosys is not installed or not in PATH${NC}"
    echo "Please install Yosys from: https://github.com/YosysHQ/yosys"
    exit 1
fi

# Check if SBY config file exists
if [ ! -f "$DESIGN_DIR/$SBY_FILE" ]; then
    echo -e "${RED}Error: SBY config file $SBY_FILE not found in $DESIGN_DIR${NC}"
    exit 1
fi

# Change to design directory
cd "$DESIGN_DIR"

# Function to run a specific task
run_task() {
    local task_name="$1"
    echo -e "${YELLOW}Running task: $task_name${NC}"
    echo "Command: sby -f $SBY_FILE $task_name"
    echo "----------------------------------------"
    
    if sby -f "$SBY_FILE" "$task_name"; then
        echo -e "${GREEN}✓ Task $task_name completed successfully${NC}"
        echo ""
    else
        echo -e "${RED}✗ Task $task_name failed${NC}"
        echo ""
        return 1
    fi
}

# Function to show results
show_results() {
    echo -e "${BLUE}Verification Results:${NC}"
    echo "===================="
    
    for task in bmc_basic prove_basic cover_basic; do
        result_dir="or1200_formal_${task}"
        if [ -d "$result_dir" ]; then
            echo -e "${YELLOW}Task: $task${NC}"
            if [ -f "$result_dir/status" ]; then
                status=$(cat "$result_dir/status")
                case "$status" in
                    "PASS")
                        echo -e "  Status: ${GREEN}PASS${NC}"
                        ;;
                    "FAIL")
                        echo -e "  Status: ${RED}FAIL${NC}"
                        ;;
                    "UNKNOWN")
                        echo -e "  Status: ${YELLOW}UNKNOWN${NC}"
                        ;;
                    *)
                        echo -e "  Status: ${YELLOW}$status${NC}"
                        ;;
                esac
            fi
            if [ -f "$result_dir/logfile.txt" ]; then
                echo "  Log file: $result_dir/logfile.txt"
            fi
            echo ""
        fi
    done
}

# Parse command line arguments
TASK=""
SHOW_HELP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            SHOW_HELP=true
            shift
            ;;
        -t|--task)
            TASK="$2"
            shift 2
            ;;
        *)
            TASK="$1"
            shift
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    echo "Usage: $0 [OPTIONS] [TASK]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -t, --task     Run specific task (bmc_basic, prove_basic, cover_basic)"
    echo ""
    echo "Tasks:"
    echo "  bmc_basic      Bounded Model Checking (depth 20)"
    echo "  prove_basic    Inductive proof (depth 10)"  
    echo "  cover_basic    Coverage checking (depth 50)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all tasks"
    echo "  $0 bmc_basic         # Run only BMC task"
    echo "  $0 -t prove_basic    # Run only prove task"
    exit 0
fi

# Clean up old results
echo -e "${YELLOW}Cleaning up old results...${NC}"
rm -rf or1200_formal_*

# Run specific task or all tasks
if [ -n "$TASK" ]; then
    case "$TASK" in
        bmc_basic|prove_basic|cover_basic)
            echo "running only task: $TASK"
            run_task "$TASK"
            ;;
        *)
            echo -e "${RED}Error: Unknown task '$TASK'${NC}"
            echo "Available tasks: bmc_basic, prove_basic, cover_basic"
            exit 1
            ;;
    esac
else
    # Run all tasks
    echo -e "${YELLOW}Running all formal verification tasks...${NC}"
    echo ""
    
    FAILED_TASKS=()
    
    for task in bmc_basic prove_basic cover_basic; do
        if ! run_task "$task"; then
            FAILED_TASKS+=("$task")
        fi
    done
    
    # Show summary
    echo "========================================="
    if [ ${#FAILED_TASKS[@]} -eq 0 ]; then
        echo -e "${GREEN}All tasks completed successfully!${NC}"
    else
        echo -e "${RED}Some tasks failed: ${FAILED_TASKS[*]}${NC}"
    fi
fi

# Show results
echo ""
show_results

echo -e "${BLUE}Formal verification completed.${NC}"