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

echo -e "\n${YELLOW}=====================================${NC}"
echo -e "${YELLOW}        Test Summary                ${NC}"
echo -e "${YELLOW}=====================================${NC}"

if [ $BASIC_EXIT -eq 0 ] && [ $EXTENDED_EXIT -eq 0 ] && [ $ENV_OVERRIDE_EXIT -eq 0 ]; then
    echo -e "${GREEN}ALL TESTS PASSED!${NC}"
    exit 0
else
    echo -e "${RED}SOME TESTS FAILED!${NC}"
    [ $BASIC_EXIT -ne 0 ] && echo -e "${RED}Basic tests failed.${NC}"
    [ $EXTENDED_EXIT -ne 0 ] && echo -e "${RED}Extended tests failed.${NC}"
    [ $ENV_OVERRIDE_EXIT -ne 0 ] && echo -e "${RED}Environment override tests failed.${NC}"
    exit 1
fi 