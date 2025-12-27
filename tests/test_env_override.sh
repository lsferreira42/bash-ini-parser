#!/bin/bash

# Load the library
source ${PWD%%/tests*}/lib_ini.sh

# Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run tests
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_result="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo -e "${YELLOW}Running test: ${test_name}${NC}"
    
    # Execute the command
    result=$(eval "${test_cmd}" 2>&1)
    exit_code=$?
    
    # Compare results normalizing line breaks
    expected_normalized=$(echo -e "$expected_result" | tr -d '\r')
    result_normalized=$(echo -e "$result" | tr -d '\r')
    
    if [[ "$result_normalized" == "$expected_normalized" && ${exit_code} -eq 0 ]]; then
        echo -e "${GREEN}✓ Test passed${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed${NC}"
        echo -e "  Expected: '${expected_result}'"
        echo -e "  Got:      '${result}'"
        echo -e "  Exit code: ${exit_code}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to test expected failures
run_test_failure() {
    local test_name="$1"
    local test_cmd="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo -e "${YELLOW}Running failure test: ${test_name}${NC}"
    
    # Execute command but expect failure
    eval "${test_cmd}" > /dev/null 2>&1
    exit_code=$?
    
    if [[ ${exit_code} -ne 0 ]]; then
        echo -e "${GREEN}✓ Test passed (expected failure)${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ Test failed (should have failed but passed)${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "===================================="
echo "Testing Environment Variable Override"
echo "===================================="

# Create a test file
TEST_FILE=$(mktemp)
echo "[test]" > "${TEST_FILE}"
echo "key=value" >> "${TEST_FILE}"

# Test default configuration
echo -e "\n${YELLOW}Tests for Default Configuration${NC}"

# Test that defaults are set correctly (already sourced at top)
run_test "Default INI_DEBUG" "echo ${INI_DEBUG:-0}" "0"
run_test "Default INI_STRICT" "echo ${INI_STRICT:-0}" "0"
run_test "Default INI_ALLOW_EMPTY_VALUES" "echo ${INI_ALLOW_EMPTY_VALUES:-1}" "1"
run_test "Default INI_ALLOW_SPACES_IN_NAMES" "echo ${INI_ALLOW_SPACES_IN_NAMES:-1}" "1"

# Test environment variable override
echo -e "\n${YELLOW}Tests for Environment Variable Override${NC}"

# Test INI_DEBUG override
run_test "Override INI_DEBUG=1" "INI_DEBUG=1 bash -c 'source ${PWD%%/tests*}/lib_ini.sh > /dev/null 2>&1; echo \$INI_DEBUG'" "1"

# Test INI_STRICT override
run_test "Override INI_STRICT=1" "INI_STRICT=1 bash -c 'source ${PWD%%/tests*}/lib_ini.sh > /dev/null 2>&1; echo \$INI_STRICT'" "1"

# Test INI_ALLOW_EMPTY_VALUES override
run_test "Override INI_ALLOW_EMPTY_VALUES=0" "INI_ALLOW_EMPTY_VALUES=0 bash -c 'source ${PWD%%/tests*}/lib_ini.sh > /dev/null 2>&1; echo \$INI_ALLOW_EMPTY_VALUES'" "0"

# Test INI_ALLOW_SPACES_IN_NAMES override
run_test "Override INI_ALLOW_SPACES_IN_NAMES=0" "INI_ALLOW_SPACES_IN_NAMES=0 bash -c 'source ${PWD%%/tests*}/lib_ini.sh > /dev/null 2>&1; echo \$INI_ALLOW_SPACES_IN_NAMES'" "0"

# Test INI_MAX_FILE_SIZE override
run_test "Override INI_MAX_FILE_SIZE=5000" "INI_MAX_FILE_SIZE=5000 bash -c 'source ${PWD%%/tests*}/lib_ini.sh > /dev/null 2>&1; echo \$INI_MAX_FILE_SIZE'" "5000"

# Test that override affects behavior
echo -e "\n${YELLOW}Tests for Override Behavior${NC}"

# Test INI_STRICT mode behavior
STRICT_TEST=$(mktemp)
# Test that INI_STRICT=1 rejects section with = character (using run_test_failure since we expect failure)
run_test_failure "INI_STRICT=1 rejects invalid section" "INI_STRICT=1 bash -c 'source ${PWD%%/tests*}/lib_ini.sh > /dev/null 2>&1; ini_validate_section_name \"section=invalid\" 2>&1 > /dev/null; [ \$? -ne 0 ]'"

# Test INI_ALLOW_EMPTY_VALUES=0 behavior
EMPTY_TEST=$(mktemp)
run_test "INI_ALLOW_EMPTY_VALUES=0 rejects empty values" "INI_ALLOW_EMPTY_VALUES=0 bash -c 'source ${PWD%%/tests*}/lib_ini.sh > /dev/null 2>&1; ini_write \"${EMPTY_TEST}\" \"test\" \"key\" \"\" > /dev/null 2>&1; echo \$?'" "1"

# Test INI_ALLOW_SPACES_IN_NAMES=0 behavior
SPACES_TEST=$(mktemp)
run_test "INI_ALLOW_SPACES_IN_NAMES=0 rejects spaces" "INI_ALLOW_SPACES_IN_NAMES=0 bash -c 'source ${PWD%%/tests*}/lib_ini.sh > /dev/null 2>&1; ini_validate_section_name \"section with spaces\" > /dev/null 2>&1; echo \$?'" "1"

# Cleanup
rm -f "${TEST_FILE}" "${STRICT_TEST}" "${EMPTY_TEST}" "${SPACES_TEST}"

# -------------------------------
# Test summary
# -------------------------------
echo -e "\n===================================="
echo -e "${YELLOW}ENVIRONMENT OVERRIDE TEST SUMMARY${NC}"
echo -e "===================================="
echo -e "Total environment override tests executed: ${TESTS_TOTAL}"
echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"

if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "\n${GREEN}ALL ENVIRONMENT OVERRIDE TESTS PASSED!${NC}"
    exit 0
else
    echo -e "\n${RED}ENVIRONMENT OVERRIDE TEST FAILURES!${NC}"
    exit 1
fi
