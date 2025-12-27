#!/bin/bash

# Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}  Running All bash_ini_parser Tests  ${NC}"
echo -e "${YELLOW}=====================================${NC}\n"

# First run the basic tests
echo -e "${YELLOW}Running Basic Tests...${NC}"
bash tests/lib_ini_tests.sh

BASIC_EXIT=$?

# Then run the extended tests
echo -e "\n${YELLOW}Running Extended Tests...${NC}"
bash tests/lib_ini_extended_tests.sh

EXTENDED_EXIT=$?

# Now run the environment override tests
echo -e "\n${YELLOW}Running Environment Override Tests...${NC}"
bash tests/test_env_override.sh

ENV_OVERRIDE_EXIT=$?

# Now run the security tests
echo -e "\n${YELLOW}Running Security Tests...${NC}"
bash tests/lib_ini_security_tests.sh

SECURITY_EXIT=$?

# Now run the advanced features tests
echo -e "\n${YELLOW}Running Advanced Features Tests...${NC}"
bash tests/lib_ini_advanced_features_tests.sh

ADVANCED_EXIT=$?

# Extract test counts from each test suite
BASIC_TOTAL=$(bash tests/lib_ini_tests.sh 2>&1 | grep -oP 'Total tests executed: \K\d+' || echo "0")
BASIC_PASSED=$(bash tests/lib_ini_tests.sh 2>&1 | grep -oP 'Tests passed: \K\d+' || echo "0")
BASIC_FAILED=$(bash tests/lib_ini_tests.sh 2>&1 | grep -oP 'Tests failed: \K\d+' || echo "0")

EXTENDED_TOTAL=$(bash tests/lib_ini_extended_tests.sh 2>&1 | grep -oP 'Total extended tests executed: \K\d+' || echo "0")
EXTENDED_PASSED=$(bash tests/lib_ini_extended_tests.sh 2>&1 | grep -oP 'Tests passed: \K\d+' || echo "0")
EXTENDED_FAILED=$(bash tests/lib_ini_extended_tests.sh 2>&1 | grep -oP 'Tests failed: \K\d+' || echo "0")

ENV_TOTAL=$(bash tests/test_env_override.sh 2>&1 | grep -oP 'Total environment override tests executed: \K\d+' || echo "0")
ENV_PASSED=$(bash tests/test_env_override.sh 2>&1 | grep -oP 'Tests passed: \K\d+' || echo "0")
ENV_FAILED=$(bash tests/test_env_override.sh 2>&1 | grep -oP 'Tests failed: \K\d+' || echo "0")

SECURITY_TOTAL=$(bash tests/lib_ini_security_tests.sh 2>&1 | grep -oP 'Total security tests executed: \K\d+' || echo "0")
SECURITY_PASSED=$(bash tests/lib_ini_security_tests.sh 2>&1 | grep -oP 'Tests passed: \K\d+' || echo "0")
SECURITY_FAILED=$(bash tests/lib_ini_security_tests.sh 2>&1 | grep -oP 'Tests failed: \K\d+' || echo "0")

ADVANCED_TOTAL=$(bash tests/lib_ini_advanced_features_tests.sh 2>&1 | grep -oP 'Total advanced features tests executed: \K\d+' || echo "0")
ADVANCED_PASSED=$(bash tests/lib_ini_advanced_features_tests.sh 2>&1 | grep -oP 'Tests passed: \K\d+' || echo "0")
ADVANCED_FAILED=$(bash tests/lib_ini_advanced_features_tests.sh 2>&1 | grep -oP 'Tests failed: \K\d+' || echo "0")

# Calculate totals
TOTAL_TESTS=$((BASIC_TOTAL + EXTENDED_TOTAL + ENV_TOTAL + SECURITY_TOTAL + ADVANCED_TOTAL))
TOTAL_PASSED=$((BASIC_PASSED + EXTENDED_PASSED + ENV_PASSED + SECURITY_PASSED + ADVANCED_PASSED))
TOTAL_FAILED=$((BASIC_FAILED + EXTENDED_FAILED + ENV_FAILED + SECURITY_FAILED + ADVANCED_FAILED))

echo -e "\n${YELLOW}=====================================${NC}"
echo -e "${YELLOW}        Test Summary                ${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo -e "Basic tests:        ${BASIC_TOTAL} executed, ${GREEN}${BASIC_PASSED} passed${NC}, ${RED}${BASIC_FAILED} failed${NC}"
echo -e "Extended tests:     ${EXTENDED_TOTAL} executed, ${GREEN}${EXTENDED_PASSED} passed${NC}, ${RED}${EXTENDED_FAILED} failed${NC}"
echo -e "Environment tests:  ${ENV_TOTAL} executed, ${GREEN}${ENV_PASSED} passed${NC}, ${RED}${ENV_FAILED} failed${NC}"
echo -e "Security tests:     ${SECURITY_TOTAL} executed, ${GREEN}${SECURITY_PASSED} passed${NC}, ${RED}${SECURITY_FAILED} failed${NC}"
echo -e "Advanced tests:     ${ADVANCED_TOTAL} executed, ${GREEN}${ADVANCED_PASSED} passed${NC}, ${RED}${ADVANCED_FAILED} failed${NC}"
echo -e "${YELLOW}-------------------------------------${NC}"
echo -e "Total:              ${TOTAL_TESTS} executed, ${GREEN}${TOTAL_PASSED} passed${NC}, ${RED}${TOTAL_FAILED} failed${NC}"

if [ $BASIC_EXIT -eq 0 ] && [ $EXTENDED_EXIT -eq 0 ] && [ $ENV_OVERRIDE_EXIT -eq 0 ] && [ $SECURITY_EXIT -eq 0 ] && [ $ADVANCED_EXIT -eq 0 ]; then
    echo -e "\n${GREEN}ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "\n${RED}SOME TESTS FAILED!${NC}"
    [ $BASIC_EXIT -ne 0 ] && echo -e "${RED}Basic tests failed.${NC}"
    [ $EXTENDED_EXIT -ne 0 ] && echo -e "${RED}Extended tests failed.${NC}"
    [ $ENV_OVERRIDE_EXIT -ne 0 ] && echo -e "${RED}Environment override tests failed.${NC}"
    [ $SECURITY_EXIT -ne 0 ] && echo -e "${RED}Security tests failed.${NC}"
    [ $ADVANCED_EXIT -ne 0 ] && echo -e "${RED}Advanced features tests failed.${NC}"
    exit 1
fi 