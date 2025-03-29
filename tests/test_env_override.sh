#!/bin/bash

echo "Testing environment variable override functionality"
echo

# First run without environment variables set
echo "=== Default configuration ==="
# Make sure these variables are not set in the environment
unset INI_DEBUG INI_STRICT INI_ALLOW_EMPTY_VALUES INI_ALLOW_SPACES_IN_NAMES

# Source the library
source ./lib_ini.sh
echo "INI_DEBUG=${INI_DEBUG}"
echo "INI_STRICT=${INI_STRICT}"
echo "INI_ALLOW_EMPTY_VALUES=${INI_ALLOW_EMPTY_VALUES}"
echo "INI_ALLOW_SPACES_IN_NAMES=${INI_ALLOW_SPACES_IN_NAMES}"
echo

# Now set environment variables and test in a subshell
echo "=== Override with environment variables ==="
(
    # In a subshell, set environment variables
    export INI_DEBUG=1
    export INI_STRICT=1
    export INI_ALLOW_EMPTY_VALUES=0
    export INI_ALLOW_SPACES_IN_NAMES=0
    
    # Source the library again
    source ./lib_ini.sh
    
    echo "INI_DEBUG=${INI_DEBUG}"
    echo "INI_STRICT=${INI_STRICT}"
    echo "INI_ALLOW_EMPTY_VALUES=${INI_ALLOW_EMPTY_VALUES}"
    echo "INI_ALLOW_SPACES_IN_NAMES=${INI_ALLOW_SPACES_IN_NAMES}"
)
echo

echo "Test completed!" 