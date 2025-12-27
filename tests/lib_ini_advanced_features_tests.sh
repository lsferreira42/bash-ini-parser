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
echo "Testing Advanced Features"
echo "===================================="

# -------------------------------
# Test 1: ini_validate()
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_validate()${NC}"

# Create valid INI file
VALID_FILE=$(mktemp)
echo "[section1]" > "${VALID_FILE}"
echo "key1=value1" >> "${VALID_FILE}"
echo "[section2]" >> "${VALID_FILE}"
echo "key2=value2" >> "${VALID_FILE}"

run_test "ini_validate - valid file" "ini_validate '${VALID_FILE}' && echo 'OK'" "OK"

# Create invalid INI file (key outside section)
INVALID_FILE=$(mktemp)
echo "key=value" > "${INVALID_FILE}"
echo "[section]" >> "${INVALID_FILE}"
echo "key2=value2" >> "${INVALID_FILE}"

run_test_failure "ini_validate - invalid file (key outside section)" "ini_validate '${INVALID_FILE}'"

# Test with empty file
EMPTY_VALID_FILE=$(mktemp)
run_test "ini_validate - empty file" "ini_validate '${EMPTY_VALID_FILE}' && echo 'OK'" "OK"

# Test with file containing only comments
COMMENT_FILE=$(mktemp)
echo "# This is a comment" > "${COMMENT_FILE}"
echo "; Another comment" >> "${COMMENT_FILE}"
run_test "ini_validate - file with only comments" "ini_validate '${COMMENT_FILE}' && echo 'OK'" "OK"

# -------------------------------
# Test 2: ini_get_all()
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_get_all()${NC}"

GET_ALL_FILE=$(mktemp)
echo "[app]" > "${GET_ALL_FILE}"
echo "name=MyApp" >> "${GET_ALL_FILE}"
echo "version=1.0" >> "${GET_ALL_FILE}"
echo "debug=true" >> "${GET_ALL_FILE}"

# Test getting all keys from a section
run_test "ini_get_all - get all keys" "ini_get_all '${GET_ALL_FILE}' 'app' | sort | tr '\n' ',' | sed 's/,$//'" "debug=true,name=MyApp,version=1.0"

# Test with non-existent section
run_test "ini_get_all - non-existent section" "ini_get_all '${GET_ALL_FILE}' 'nonexistent'" ""

# Test with empty section
EMPTY_SECTION_FILE=$(mktemp)
echo "[empty]" > "${EMPTY_SECTION_FILE}"
run_test "ini_get_all - empty section" "ini_get_all '${EMPTY_SECTION_FILE}' 'empty'" ""

# -------------------------------
# Test 3: ini_rename_section()
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_rename_section()${NC}"

RENAME_SECTION_FILE=$(mktemp)
echo "[old_section]" > "${RENAME_SECTION_FILE}"
echo "key1=value1" >> "${RENAME_SECTION_FILE}"
echo "key2=value2" >> "${RENAME_SECTION_FILE}"
echo "[other_section]" >> "${RENAME_SECTION_FILE}"
echo "key3=value3" >> "${RENAME_SECTION_FILE}"

run_test "ini_rename_section - rename section" "ini_rename_section '${RENAME_SECTION_FILE}' 'old_section' 'new_section' && ini_section_exists '${RENAME_SECTION_FILE}' 'new_section' && echo 'OK'" "OK"

# Verify keys are preserved
run_test "ini_rename_section - keys preserved" "ini_read '${RENAME_SECTION_FILE}' 'new_section' 'key1'" "value1"

# Test renaming non-existent section
run_test_failure "ini_rename_section - non-existent section" "ini_rename_section '${RENAME_SECTION_FILE}' 'nonexistent' 'new_name'"

# Test renaming to existing section
run_test_failure "ini_rename_section - target section exists" "ini_rename_section '${RENAME_SECTION_FILE}' 'new_section' 'other_section'"

# -------------------------------
# Test 4: ini_rename_key()
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_rename_key()${NC}"

RENAME_KEY_FILE=$(mktemp)
echo "[section]" > "${RENAME_KEY_FILE}"
echo "old_key=old_value" >> "${RENAME_KEY_FILE}"
echo "other_key=other_value" >> "${RENAME_KEY_FILE}"

run_test "ini_rename_key - rename key" "ini_rename_key '${RENAME_KEY_FILE}' 'section' 'old_key' 'new_key' && ini_read '${RENAME_KEY_FILE}' 'section' 'new_key'" "old_value"

# Verify old key is removed
run_test_failure "ini_rename_key - old key removed" "ini_read '${RENAME_KEY_FILE}' 'section' 'old_key'"

# Test renaming non-existent key
run_test_failure "ini_rename_key - non-existent key" "ini_rename_key '${RENAME_KEY_FILE}' 'section' 'nonexistent' 'new_name'"

# Test renaming to existing key
run_test_failure "ini_rename_key - target key exists" "ini_rename_key '${RENAME_KEY_FILE}' 'section' 'new_key' 'other_key'"

# -------------------------------
# Test 5: ini_format()
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_format()${NC}"

FORMAT_FILE=$(mktemp)
echo "[section1]" > "${FORMAT_FILE}"
echo "key2=value2" >> "${FORMAT_FILE}"
echo "key1=value1" >> "${FORMAT_FILE}"
echo "[section2]" >> "${FORMAT_FILE}"
echo "key3=value3" >> "${FORMAT_FILE}"

# Test formatting without options
run_test "ini_format - basic formatting" "ini_format '${FORMAT_FILE}' && ini_read '${FORMAT_FILE}' 'section1' 'key1'" "value1"

# Test formatting with sort_keys
FORMAT_SORT_FILE=$(mktemp)
echo "[section]" > "${FORMAT_SORT_FILE}"
echo "key2=value2" >> "${FORMAT_SORT_FILE}"
echo "key1=value1" >> "${FORMAT_SORT_FILE}"
echo "key3=value3" >> "${FORMAT_SORT_FILE}"

run_test "ini_format - with sort_keys" "ini_format '${FORMAT_SORT_FILE}' 0 1 && ini_list_keys '${FORMAT_SORT_FILE}' 'section' | sort | tr '\n' ',' | sed 's/,$//'" "key1,key2,key3"

# Verify file is still readable after formatting
run_test "ini_format - file still readable" "ini_read '${FORMAT_FILE}' 'section1' 'key1'" "value1"

# -------------------------------
# Test 6: ini_batch_write()
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_batch_write()${NC}"

BATCH_FILE=$(mktemp)

# Test batch writing multiple key-value pairs
run_test "ini_batch_write - multiple pairs" "ini_batch_write '${BATCH_FILE}' 'batch_section' 'key1=value1' 'key2=value2' 'key3=value3' && ini_read '${BATCH_FILE}' 'batch_section' 'key2'" "value2"

# Verify all keys were written
run_test "ini_batch_write - all keys written" "ini_list_keys '${BATCH_FILE}' 'batch_section' | wc -l | tr -d '[:space:]'" "3"

# Test batch write with invalid format
run_test_failure "ini_batch_write - invalid format" "ini_batch_write '${BATCH_FILE}' 'section' 'invalid_format'"

# Test batch write creates section if needed
BATCH_NEW_FILE=$(mktemp)
run_test "ini_batch_write - creates section" "ini_batch_write '${BATCH_NEW_FILE}' 'new_section' 'key=value' && ini_section_exists '${BATCH_NEW_FILE}' 'new_section' && echo 'OK'" "OK"

# -------------------------------
# Test 7: ini_merge()
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_merge()${NC}"

MERGE_SOURCE=$(mktemp)
echo "[common]" > "${MERGE_SOURCE}"
echo "key1=source_value1" >> "${MERGE_SOURCE}"
echo "key2=source_value2" >> "${MERGE_SOURCE}"
echo "[unique_source]" >> "${MERGE_SOURCE}"
echo "key3=source_value3" >> "${MERGE_SOURCE}"

MERGE_TARGET=$(mktemp)
echo "[common]" > "${MERGE_TARGET}"
echo "key1=target_value1" >> "${MERGE_TARGET}"
echo "key4=target_value4" >> "${MERGE_TARGET}"

# Test merge with overwrite strategy
MERGE_OVERWRITE=$(mktemp)
cp "${MERGE_TARGET}" "${MERGE_OVERWRITE}"
run_test "ini_merge - overwrite strategy" "ini_merge '${MERGE_SOURCE}' '${MERGE_OVERWRITE}' 'overwrite' && ini_read '${MERGE_OVERWRITE}' 'common' 'key1'" "source_value1"

# Test merge with skip strategy
MERGE_SKIP=$(mktemp)
cp "${MERGE_TARGET}" "${MERGE_SKIP}"
run_test "ini_merge - skip strategy" "ini_merge '${MERGE_SOURCE}' '${MERGE_SKIP}' 'skip' && ini_read '${MERGE_SKIP}' 'common' 'key1'" "target_value1"

# Test merge with merge strategy
MERGE_MERGE=$(mktemp)
cp "${MERGE_TARGET}" "${MERGE_MERGE}"
run_test "ini_merge - merge strategy" "ini_merge '${MERGE_SOURCE}' '${MERGE_MERGE}' 'merge' && ini_read '${MERGE_MERGE}' 'common' 'key1'" "target_value1,source_value1"

# Test merge adds new sections
run_test "ini_merge - adds new sections" "ini_merge '${MERGE_SOURCE}' '${MERGE_OVERWRITE}' 'overwrite' && ini_section_exists '${MERGE_OVERWRITE}' 'unique_source' && echo 'OK'" "OK"

# Test merge with specific sections
MERGE_SPECIFIC=$(mktemp)
cp "${MERGE_TARGET}" "${MERGE_SPECIFIC}"
run_test "ini_merge - specific sections" "ini_merge '${MERGE_SOURCE}' '${MERGE_SPECIFIC}' 'overwrite' 'common' && ini_section_exists '${MERGE_SPECIFIC}' 'unique_source' && echo 'exists' || echo 'not_exists'" "not_exists"

# Test merge with invalid strategy
run_test_failure "ini_merge - invalid strategy" "ini_merge '${MERGE_SOURCE}' '${MERGE_TARGET}' 'invalid_strategy'"

# -------------------------------
# Test 8: ini_to_json()
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_to_json()${NC}"

JSON_FILE=$(mktemp)
echo "[app]" > "${JSON_FILE}"
echo "name=MyApp" >> "${JSON_FILE}"
echo "version=1.0" >> "${JSON_FILE}"

# Test JSON conversion (compact)
JSON_OUTPUT=$(ini_to_json "${JSON_FILE}" 0 2>&1)
run_test "ini_to_json - compact format" "ini_to_json '${JSON_FILE}' 0 2>&1 | grep -o '\"app\"' | head -1" "\"app\""

# Test JSON conversion (pretty)
JSON_PRETTY=$(ini_to_json "${JSON_FILE}" 1 2>&1)
run_test "ini_to_json - pretty format" "ini_to_json '${JSON_FILE}' 1 2>&1 | grep -q '\"app\"' && echo 'OK'" "OK"

# Test JSON contains correct values
run_test "ini_to_json - contains values" "ini_to_json '${JSON_FILE}' 0 2>&1 | grep -o '\"name\":\"MyApp\"'" "\"name\":\"MyApp\""

# Test JSON with special characters
JSON_SPECIAL=$(mktemp)
echo "[section]" > "${JSON_SPECIAL}"
echo "key=\"value with quotes\"" >> "${JSON_SPECIAL}"
run_test "ini_to_json - special characters" "ini_to_json '${JSON_SPECIAL}' 0 2>&1 | grep -q 'section' && echo 'OK'" "OK"

# -------------------------------
# Test 9: ini_to_yaml()
# -------------------------------
echo -e "\n${YELLOW}Tests for ini_to_yaml()${NC}"

YAML_FILE=$(mktemp)
echo "[app]" > "${YAML_FILE}"
echo "name=MyApp" >> "${YAML_FILE}"
echo "version=1.0" >> "${YAML_FILE}"

# Test YAML conversion
run_test "ini_to_yaml - basic conversion" "ini_to_yaml '${YAML_FILE}' 2>&1 | grep -q 'app:' && echo 'OK'" "OK"

# Test YAML contains correct values
run_test "ini_to_yaml - contains values" "ini_to_yaml '${YAML_FILE}' 2>&1 | grep -q 'name:' && echo 'OK'" "OK"

# Test YAML with multiple sections
YAML_MULTI=$(mktemp)
echo "[section1]" > "${YAML_MULTI}"
echo "key1=value1" >> "${YAML_MULTI}"
echo "[section2]" >> "${YAML_MULTI}"
echo "key2=value2" >> "${YAML_MULTI}"
run_test "ini_to_yaml - multiple sections" "ini_to_yaml '${YAML_MULTI}' 2>&1 | grep -E '^(section|  key)' | wc -l | tr -d '[:space:]'" "4"

# Test YAML with custom indent
run_test "ini_to_yaml - custom indent" "ini_to_yaml '${YAML_FILE}' 4 2>&1 | grep -q '    name:' && echo 'OK'" "OK"

# -------------------------------
# Additional Edge Cases
# -------------------------------
echo -e "\n${YELLOW}Additional Edge Cases${NC}"

# Test ini_validate with strict mode
STRICT_VALIDATE_FILE=$(mktemp)
echo "[valid-section]" > "${STRICT_VALIDATE_FILE}"
echo "valid_key=value" >> "${STRICT_VALIDATE_FILE}"
export INI_STRICT=1
run_test "ini_validate - strict mode valid" "ini_validate '${STRICT_VALIDATE_FILE}' && echo 'OK'" "OK"

# Test ini_get_all with quoted values
QUOTED_FILE=$(mktemp)
echo "[section]" > "${QUOTED_FILE}"
echo "key1=\"quoted value\"" >> "${QUOTED_FILE}"
echo "key2=normal" >> "${QUOTED_FILE}"
run_test "ini_get_all - with quoted values" "ini_get_all '${QUOTED_FILE}' 'section' | grep -c '=' | tr -d '[:space:]'" "2"

# Test ini_format preserves comments
COMMENT_FORMAT_FILE=$(mktemp)
echo "# Comment before" > "${COMMENT_FORMAT_FILE}"
echo "[section]" >> "${COMMENT_FORMAT_FILE}"
echo "# Comment in section" >> "${COMMENT_FORMAT_FILE}"
echo "key=value" >> "${COMMENT_FORMAT_FILE}"
run_test "ini_format - preserves structure" "ini_format '${COMMENT_FORMAT_FILE}' && ini_read '${COMMENT_FORMAT_FILE}' 'section' 'key'" "value"

# Cleanup
rm -f "${VALID_FILE}" "${INVALID_FILE}" "${EMPTY_VALID_FILE}" "${COMMENT_FILE}" \
      "${GET_ALL_FILE}" "${EMPTY_SECTION_FILE}" "${RENAME_SECTION_FILE}" \
      "${RENAME_KEY_FILE}" "${FORMAT_FILE}" "${FORMAT_SORT_FILE}" \
      "${BATCH_FILE}" "${BATCH_NEW_FILE}" "${MERGE_SOURCE}" "${MERGE_TARGET}" \
      "${MERGE_OVERWRITE}" "${MERGE_SKIP}" "${MERGE_MERGE}" "${MERGE_SPECIFIC}" \
      "${JSON_FILE}" "${JSON_SPECIAL}" "${YAML_FILE}" "${YAML_MULTI}" \
      "${STRICT_VALIDATE_FILE}" "${QUOTED_FILE}" "${COMMENT_FORMAT_FILE}"

# Restore INI_STRICT
unset INI_STRICT

# -------------------------------
# Test summary
# -------------------------------
echo -e "\n===================================="
echo -e "${YELLOW}ADVANCED FEATURES TEST SUMMARY${NC}"
echo -e "===================================="
echo -e "Total advanced features tests executed: ${TESTS_TOTAL}"
echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"

if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "\n${GREEN}ALL ADVANCED FEATURES TESTS PASSED!${NC}"
    exit 0
else
    echo -e "\n${RED}ADVANCED FEATURES TEST FAILURES!${NC}"
    exit 1
fi

