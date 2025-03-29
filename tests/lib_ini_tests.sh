#!/bin/bash

# Load the library
source ${PWD%%/tests*}/lib_ini.sh

# Define the examples directory path
EXAMPLES_DIR="${PWD%%/tests*}/examples"

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
    result=$(eval "${test_cmd}")
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

# Create a temporary ini file for tests
create_temp_ini() {
    local temp_file=$(mktemp)
    echo "[test]" > "${temp_file}"
    echo "key1=value1" >> "${temp_file}"
    echo "key2=value2" >> "${temp_file}"
    echo "" >> "${temp_file}"
    echo "[other_section]" >> "${temp_file}"
    echo "key3=value3" >> "${temp_file}"
    echo "${temp_file}"
}

echo "===================================="
echo "Starting lib_ini.sh tests"
echo "===================================="

# -------------------------------
# Unit tests - ini_check_file
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_check_file${NC}"

# Test for an existing file
TEST_FILE=$(mktemp)
run_test "ini_check_file - existing file" "ini_check_file '${TEST_FILE}' && echo 'OK'" "OK"

# Test for a non-existing file (should be created)
rm -f /tmp/test_not_exists.ini
run_test "ini_check_file - create file" "ini_check_file '/tmp/test_not_exists.ini' && echo 'OK'" "OK"

# Test for a directory without permission (should fail)
if [ -w "/root" ]; then
    run_test_failure "ini_check_file - no permission" "ini_check_file '/root/test_no_permission.ini'"
else
    echo -e "${YELLOW}Skipping permission test because we are not running as root${NC}"
fi

# -------------------------------
# Unit tests - ini_read
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_read${NC}"

# Reading a simple value
run_test "ini_read - simple value" "ini_read '${EXAMPLES_DIR}/simple.ini' 'app' 'name'" "Meu Aplicativo"

# Reading a numeric value
run_test "ini_read - numeric value" "ini_read '${EXAMPLES_DIR}/simple.ini' 'database' 'port'" "3306"

# Reading a boolean value
run_test "ini_read - boolean value" "ini_read '${EXAMPLES_DIR}/simple.ini' 'app' 'debug'" "false"

# Reading a value with spaces and special characters
run_test "ini_read - complex value" "ini_read '${EXAMPLES_DIR}/complex.ini' 'sistema' 'descrição'" "Este é um sistema complexo com várias funcionalidades"

# Reading a value with file path
run_test "ini_read - value with path" "ini_read '${EXAMPLES_DIR}/complex.ini' 'configurações' 'diretório de dados'" "C:\\Programa Files\\Sistema\\data"

# Reading a value with URL
run_test "ini_read - value with URL" "ini_read '${EXAMPLES_DIR}/complex.ini' 'configurações' 'URL'" "https://sistema.exemplo.com.br/api?token=abc123"

# Failure when reading a non-existent value
run_test_failure "ini_read - non-existent key" "ini_read '${EXAMPLES_DIR}/simple.ini' 'app' 'nao_existe'"

# Failure when reading a non-existent section
run_test_failure "ini_read - non-existent section" "ini_read '${EXAMPLES_DIR}/simple.ini' 'nao_existe' 'name'"

# Failure when reading a non-existent file
run_test_failure "ini_read - non-existent file" "ini_read '/not/exists.ini' 'app' 'name'"

# -------------------------------
# Unit tests - ini_list_sections
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_list_sections${NC}"

# List sections in a simple file
run_test "ini_list_sections - simple file" "ini_list_sections '${EXAMPLES_DIR}/simple.ini' | sort | tr '\n' ' ' | xargs" "app database"

# List sections in a complex file
run_test "ini_list_sections - complex file" "ini_list_sections '${EXAMPLES_DIR}/complex.ini' | sort | tr '\n' ' ' | xargs" "configurações sistema usuários"

# List sections in an empty file
run_test "ini_list_sections - empty file" "ini_list_sections '${EXAMPLES_DIR}/empty.ini'" ""

# List sections in an extensive file
run_test "ini_list_sections - extensive file" "ini_list_sections '${EXAMPLES_DIR}/extensive.ini' | wc -l | tr -d '[:space:]'" "11"

# Error when listing sections of a non-existent file
run_test_failure "ini_list_sections - non-existent file" "ini_list_sections '/not/exists.ini'"

# -------------------------------
# Unit tests - ini_list_keys
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_list_keys${NC}"

# List keys in a section
run_test "ini_list_keys - app section" "ini_list_keys '${EXAMPLES_DIR}/simple.ini' 'app' | sort | tr '\n' ' ' | xargs" "debug name version"

# List keys in a section with complex names
run_test "ini_list_keys - section with complex names" "ini_list_keys '${EXAMPLES_DIR}/complex.ini' 'configurações' | wc -l | tr -d '[:space:]'" "5"

# List keys in a non-existent section
run_test "ini_list_keys - non-existent section" "ini_list_keys '${EXAMPLES_DIR}/simple.ini' 'nao_existe'" ""

# -------------------------------
# Unit tests - ini_section_exists
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_section_exists${NC}"

# Check existing section
run_test "ini_section_exists - existing section" "ini_section_exists '${EXAMPLES_DIR}/simple.ini' 'app' && echo 'true'" "true"

# Check non-existent section
run_test_failure "ini_section_exists - non-existent section" "ini_section_exists '${EXAMPLES_DIR}/simple.ini' 'nao_existe'"

# -------------------------------
# Unit tests - ini_add_section
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_add_section${NC}"

# Add section to existing file
TEST_FILE=$(mktemp)
echo "[existing]" > "${TEST_FILE}"
echo "key=value" >> "${TEST_FILE}"
run_test "ini_add_section - add new section" "ini_add_section '${TEST_FILE}' 'new_section' && grep -q '\\[new_section\\]' '${TEST_FILE}' && echo 'OK'" "OK"

# Add section to empty file
TEST_FILE=$(mktemp)
run_test "ini_add_section - add to empty file" "ini_add_section '${TEST_FILE}' 'first_section' && grep -q '\\[first_section\\]' '${TEST_FILE}' && echo 'OK'" "OK"

# Add existing section (should not duplicate)
TEST_FILE=$(mktemp)
echo "[existing]" > "${TEST_FILE}"
run_test "ini_add_section - don't duplicate section" "ini_add_section '${TEST_FILE}' 'existing' && grep -c '\\[existing\\]' '${TEST_FILE}' | tr -d '[:space:]'" "1"

# -------------------------------
# Unit tests - ini_write
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_write${NC}"

# Write value to existing section
TEST_FILE=$(mktemp)
echo "[test]" > "${TEST_FILE}"
echo "existing=value" >> "${TEST_FILE}"
run_test "ini_write - new key in existing section" "ini_write '${TEST_FILE}' 'test' 'new' 'new_value' && ini_read '${TEST_FILE}' 'test' 'new'" "new_value"

# Write value to non-existent section (should create)
TEST_FILE=$(mktemp)
run_test "ini_write - new section and key" "ini_write '${TEST_FILE}' 'new_section' 'key' 'value' && ini_read '${TEST_FILE}' 'new_section' 'key'" "value"

# Update existing value
TEST_FILE=$(mktemp)
echo "[test]" > "${TEST_FILE}"
echo "key=old_value" >> "${TEST_FILE}"
run_test "ini_write - update existing value" "ini_write '${TEST_FILE}' 'test' 'key' 'new_value' && ini_read '${TEST_FILE}' 'test' 'key'" "new_value"

# Write value with special characters
TEST_FILE=$(mktemp)
run_test "ini_write - value with special characters" "ini_write '${TEST_FILE}' 'test' 'key' 'value with spaces and symbols !@#$%^&*()' && ini_read '${TEST_FILE}' 'test' 'key'" "value with spaces and symbols !@#$%^&*()"

# -------------------------------
# Unit tests - ini_remove_section
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_remove_section${NC}"

# Remove existing section
TEST_FILE=$(create_temp_ini)
run_test "ini_remove_section - remove existing section" "ini_remove_section '${TEST_FILE}' 'test' && ! grep -q '\\[test\\]' '${TEST_FILE}' && echo 'OK'" "OK"

# Try to remove non-existent section (should not fail)
TEST_FILE=$(create_temp_ini)
run_test "ini_remove_section - try to remove non-existent section" "ini_remove_section '${TEST_FILE}' 'not_exists' && echo 'OK'" "OK"

# Remove section and check if other sections remain
TEST_FILE=$(create_temp_ini)
run_test "ini_remove_section - preserve other sections" "ini_remove_section '${TEST_FILE}' 'test' && grep -q '\\[other_section\\]' '${TEST_FILE}' && echo 'OK'" "OK"

# -------------------------------
# Unit tests - ini_remove_key
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_remove_key${NC}"

# Remove existing key
TEST_FILE=$(create_temp_ini)
run_test "ini_remove_key - remove existing key" "ini_remove_key '${TEST_FILE}' 'test' 'key1' && ! grep -q 'key1=' '${TEST_FILE}' && echo 'OK'" "OK"

# Try to remove non-existent key (should not fail)
TEST_FILE=$(create_temp_ini)
run_test "ini_remove_key - try to remove non-existent key" "ini_remove_key '${TEST_FILE}' 'test' 'not_exists' && echo 'OK'" "OK"

# Remove key and check if other keys remain
TEST_FILE=$(create_temp_ini)
run_test "ini_remove_key - preserve other keys" "ini_remove_key '${TEST_FILE}' 'test' 'key1' && grep -q 'key2=' '${TEST_FILE}' && echo 'OK'" "OK"

# -------------------------------
# End-to-end tests (E2E)
# -------------------------------
echo -e "\n${YELLOW}End-to-end tests (E2E)${NC}"

# Complete test of creation, reading, updating and removal
E2E_FILE=$(mktemp)

run_test "E2E - Verify created file" "ini_check_file '${E2E_FILE}' && [ -f '${E2E_FILE}' ] && echo 'OK'" "OK"

run_test "E2E - Add section" "ini_add_section '${E2E_FILE}' 'config' && ini_section_exists '${E2E_FILE}' 'config' && echo 'OK'" "OK"

run_test "E2E - Write value" "ini_write '${E2E_FILE}' 'config' 'version' '1.0.0' && echo 'OK'" "OK"

run_test "E2E - Read value" "ini_read '${E2E_FILE}' 'config' 'version'" "1.0.0"

run_test "E2E - Update value" "ini_write '${E2E_FILE}' 'config' 'version' '2.0.0' && ini_read '${E2E_FILE}' 'config' 'version'" "2.0.0"

run_test "E2E - Add another section" "ini_add_section '${E2E_FILE}' 'database' && ini_section_exists '${E2E_FILE}' 'database' && echo 'OK'" "OK"

run_test "E2E - Add multiple values" "ini_write '${E2E_FILE}' 'database' 'host' 'localhost' && ini_write '${E2E_FILE}' 'database' 'port' '3306' && echo 'OK'" "OK"

run_test "E2E - List sections" "ini_list_sections '${E2E_FILE}' | sort | tr '\n' ' ' | xargs" "config database"

run_test "E2E - List keys" "ini_list_keys '${E2E_FILE}' 'database' | sort | tr '\n' ' ' | xargs" "host port"

run_test "E2E - Remove key" "ini_remove_key '${E2E_FILE}' 'database' 'port' && ! ini_read '${E2E_FILE}' 'database' 'port' > /dev/null 2>&1 && echo 'OK'" "OK"

run_test "E2E - Remove section" "ini_remove_section '${E2E_FILE}' 'database' && ! ini_section_exists '${E2E_FILE}' 'database' && echo 'OK'" "OK"

# Test on large/complex files
run_test "E2E - Reading complex file" "ini_read '${EXAMPLES_DIR}/extensive.ini' 'database_primary' 'password'" "S3cureP@55"

run_test "E2E - Count sections in large file" "ini_list_sections '${EXAMPLES_DIR}/extensive.ini' | wc -l | tr -d '[:space:]'" "11"

# Cleanup temporary files
rm -f "${TEST_FILE}" "${E2E_FILE}" "/tmp/test_not_exists.ini"

# -------------------------------
# Test summary
# -------------------------------
echo -e "\n===================================="
echo -e "${YELLOW}TEST SUMMARY${NC}"
echo -e "===================================="
echo -e "Total tests executed: ${TESTS_TOTAL}"
echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"

if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "\n${GREEN}ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "\n${RED}TEST FAILURES!${NC}"
    exit 1
fi 