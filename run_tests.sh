#!/bin/bash

# Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}  Running All bash_ini_parser Tests  ${NC}"
echo -e "${YELLOW}=====================================${NC}\n"

# Helper to run a test suite, capture output, and extract counts
run_suite() {
    local suite_name="$1"
    local suite_cmd="$2"
    local total_pattern="$3"

    echo -e "${YELLOW}Running ${suite_name}...${NC}"
    local output
    output=$(bash "$suite_cmd" 2>&1)
    local exit_code=$?
    echo "$output"

    # Extract counts from captured output
    local total passed failed
    total=$(echo "$output" | grep -oP "${total_pattern}: \\K\\d+" || echo "0")
    passed=$(echo "$output" | grep -oP 'Tests passed: \K\d+' || echo "0")
    failed=$(echo "$output" | grep -oP 'Tests failed: \K\d+' || echo "0")

    # Store results in global variables using nameref
    eval "${suite_name// /_}_TOTAL=$total"
    eval "${suite_name// /_}_PASSED=$passed"
    eval "${suite_name// /_}_FAILED=$failed"
    eval "${suite_name// /_}_EXIT=$exit_code"
}

# Run all test suites (each only once)
run_suite "BASIC" "tests/lib_ini_tests.sh" "Total tests executed"
echo ""
run_suite "EXTENDED" "tests/lib_ini_extended_tests.sh" "Total extended tests executed"
echo ""
run_suite "ENV" "tests/test_env_override.sh" "Total environment override tests executed"
echo ""
run_suite "SECURITY" "tests/lib_ini_security_tests.sh" "Total security tests executed"
echo ""
run_suite "ADVANCED" "tests/lib_ini_advanced_features_tests.sh" "Total advanced features tests executed"
echo ""
run_suite "BOM" "tests/lib_ini_bom_tests.sh" "Total BOM tests executed"

# Calculate totals
TOTAL_TESTS=$((BASIC_TOTAL + EXTENDED_TOTAL + ENV_TOTAL + SECURITY_TOTAL + ADVANCED_TOTAL + BOM_TOTAL))
TOTAL_PASSED=$((BASIC_PASSED + EXTENDED_PASSED + ENV_PASSED + SECURITY_PASSED + ADVANCED_PASSED + BOM_PASSED))
TOTAL_FAILED=$((BASIC_FAILED + EXTENDED_FAILED + ENV_FAILED + SECURITY_FAILED + ADVANCED_FAILED + BOM_FAILED))

echo -e "\n${YELLOW}=====================================${NC}"
echo -e "${YELLOW}        Test Summary                ${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo -e "Basic tests:        ${BASIC_TOTAL} executed, ${GREEN}${BASIC_PASSED} passed${NC}, ${RED}${BASIC_FAILED} failed${NC}"
echo -e "Extended tests:     ${EXTENDED_TOTAL} executed, ${GREEN}${EXTENDED_PASSED} passed${NC}, ${RED}${EXTENDED_FAILED} failed${NC}"
echo -e "Environment tests:  ${ENV_TOTAL} executed, ${GREEN}${ENV_PASSED} passed${NC}, ${RED}${ENV_FAILED} failed${NC}"
echo -e "Security tests:     ${SECURITY_TOTAL} executed, ${GREEN}${SECURITY_PASSED} passed${NC}, ${RED}${SECURITY_FAILED} failed${NC}"
echo -e "Advanced tests:     ${ADVANCED_TOTAL} executed, ${GREEN}${ADVANCED_PASSED} passed${NC}, ${RED}${ADVANCED_FAILED} failed${NC}"
echo -e "BOM support tests:  ${BOM_TOTAL} executed, ${GREEN}${BOM_PASSED} passed${NC}, ${RED}${BOM_FAILED} failed${NC}"
echo -e "${YELLOW}-------------------------------------${NC}"
echo -e "Total:              ${TOTAL_TESTS} executed, ${GREEN}${TOTAL_PASSED} passed${NC}, ${RED}${TOTAL_FAILED} failed${NC}"

if [ $BASIC_EXIT -eq 0 ] && [ $EXTENDED_EXIT -eq 0 ] && [ $ENV_EXIT -eq 0 ] && [ $SECURITY_EXIT -eq 0 ] && [ $ADVANCED_EXIT -eq 0 ] && [ $BOM_EXIT -eq 0 ]; then
    echo -e "\n${GREEN}ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "\n${RED}SOME TESTS FAILED!${NC}"
    [ $BASIC_EXIT -ne 0 ] && echo -e "${RED}Basic tests failed.${NC}"
    [ $EXTENDED_EXIT -ne 0 ] && echo -e "${RED}Extended tests failed.${NC}"
    [ $ENV_EXIT -ne 0 ] && echo -e "${RED}Environment override tests failed.${NC}"
    [ $SECURITY_EXIT -ne 0 ] && echo -e "${RED}Security tests failed.${NC}"
    [ $ADVANCED_EXIT -ne 0 ] && echo -e "${RED}Advanced features tests failed.${NC}"
    [ $BOM_EXIT -ne 0 ] && echo -e "${RED}BOM support tests failed.${NC}"
    exit 1
fi
 