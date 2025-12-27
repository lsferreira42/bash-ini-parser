#!/bin/bash
set +e
for script in $(find . -name "*.sh" -type f ! -path "./.git/*" ! -path "./lint.sh"); do
    echo "Checking $script..."
    if echo "$script" | grep -q "examples/"; then
        shellcheck -e SC1091,SC2162,SC2034,SC2154 "$script"
    elif echo "$script" | grep -q "tests/"; then
        shellcheck -e SC1091,SC2086,SC2155,SC2129,SC2034 "$script"
    else
        # For lib_ini.sh and other files, show all warnings including style
        shellcheck "$script"
    fi
done

