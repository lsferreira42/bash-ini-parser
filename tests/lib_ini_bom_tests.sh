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

# Track temporary files for cleanup
TEMP_FILES=()

# Cleanup function
cleanup() {
    local exit_code=$?
    # Remove all temporary files
    for file in "${TEMP_FILES[@]}"; do
        [ -f "$file" ] && rm -f "$file"
    done
    # Also clean up any test_bom_*.ini files in the current directory
    rm -f test_bom_*.ini
    exit $exit_code
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

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

echo "===================================="
echo "Testing UTF-8 BOM Support"
echo "===================================="

# Create test file with BOM
BOM_FILE=$(mktemp)
TEMP_FILES+=("${BOM_FILE}")
# Create file with UTF-8 BOM (EF BB BF) followed by INI content
printf '\xEF\xBB\xBF[app]\nname=MyApp\nversion=1.0\n' > "${BOM_FILE}"

# Create test file without BOM for comparison
NO_BOM_FILE=$(mktemp)
TEMP_FILES+=("${NO_BOM_FILE}")
printf '[app]\nname=MyApp\nversion=1.0\n' > "${NO_BOM_FILE}"

# Test 1: Read value from file with BOM
echo -e "\n${YELLOW}Tests for BOM handling${NC}"
run_test "ini_read - file with BOM" "ini_read '${BOM_FILE}' 'app' 'name'" "MyApp"

# Test 2: List sections from file with BOM
run_test "ini_list_sections - file with BOM" "ini_list_sections '${BOM_FILE}'" "app"

# Test 3: List keys from file with BOM
run_test "ini_list_keys - file with BOM" "ini_list_keys '${BOM_FILE}' 'app' | sort | tr '\n' ',' | sed 's/,$//'" "name,version"

# Test 4: Verify BOM doesn't affect reading (compare with file without BOM)
run_test "ini_read - BOM vs no BOM (same result)" "ini_read '${BOM_FILE}' 'app' 'version' && ini_read '${NO_BOM_FILE}' 'app' 'version' && echo 'OK'" "1.0
1.0
OK"

# Test 5: ini_get_all with BOM
run_test "ini_get_all - file with BOM" "ini_get_all '${BOM_FILE}' 'app' | wc -l | tr -d '[:space:]'" "2"

# Test 6: ini_validate with BOM
run_test "ini_validate - file with BOM" "ini_validate '${BOM_FILE}' && echo 'OK'" "OK"

# Test 7: ini_key_exists with BOM
run_test "ini_key_exists - file with BOM" "ini_key_exists '${BOM_FILE}' 'app' 'name' && echo 'OK'" "OK"

# Test 8: ini_section_exists with BOM
run_test "ini_section_exists - file with BOM" "ini_section_exists '${BOM_FILE}' 'app' && echo 'OK'" "OK"

# Test 9: ini_get_or_default with BOM
run_test "ini_get_or_default - file with BOM" "ini_get_or_default '${BOM_FILE}' 'app' 'name' 'Default'" "MyApp"

# Test 10: Complex file with BOM and multiple sections
COMPLEX_BOM_FILE=$(mktemp)
TEMP_FILES+=("${COMPLEX_BOM_FILE}")
printf '\xEF\xBB\xBF[section1]\nkey1=value1\n[section2]\nkey2=value2\n' > "${COMPLEX_BOM_FILE}"

run_test "ini_read - complex file with BOM" "ini_read '${COMPLEX_BOM_FILE}' 'section1' 'key1'" "value1"
run_test "ini_read - complex file with BOM (section2)" "ini_read '${COMPLEX_BOM_FILE}' 'section2' 'key2'" "value2"
run_test "ini_list_sections - complex file with BOM" "ini_list_sections '${COMPLEX_BOM_FILE}' | sort | tr '\n' ',' | sed 's/,$//'" "section1,section2"

# Test 11: BOM with empty first line
EMPTY_BOM_FILE=$(mktemp)
TEMP_FILES+=("${EMPTY_BOM_FILE}")
printf '\xEF\xBB\xBF\n[section]\nkey=value\n' > "${EMPTY_BOM_FILE}"

run_test "ini_read - BOM with empty first line" "ini_read '${EMPTY_BOM_FILE}' 'section' 'key'" "value"

# Test 12: BOM with comment on first line
COMMENT_BOM_FILE=$(mktemp)
TEMP_FILES+=("${COMMENT_BOM_FILE}")
printf '\xEF\xBB\xBF# Comment\n[section]\nkey=value\n' > "${COMMENT_BOM_FILE}"

run_test "ini_read - BOM with comment first line" "ini_read '${COMMENT_BOM_FILE}' 'section' 'key'" "value"

# Test 13: Verify files without BOM still work
run_test "ini_read - file without BOM (backward compatibility)" "ini_read '${NO_BOM_FILE}' 'app' 'name'" "MyApp"

# Cleanup is handled by trap

# -------------------------------
# Test summary
# -------------------------------
echo -e "\n===================================="
echo -e "${YELLOW}BOM SUPPORT TEST SUMMARY${NC}"
echo -e "===================================="
echo -e "Total BOM tests executed: ${TESTS_TOTAL}"
echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"

if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "\n${GREEN}ALL BOM SUPPORT TESTS PASSED!${NC}"
    exit 0
else
    echo -e "\n${RED}BOM SUPPORT TEST FAILURES!${NC}"
    exit 1
fi

