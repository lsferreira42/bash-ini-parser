#!/bin/bash

# Build script to generate index_poc.html from template_poc.html
# This script reads the actual files from the repository and embeds them into the template

# Exit on error
set -e

echo "Building index_poc.html from template_poc.html..."

# Check if template_poc.html exists
if [ ! -f "template_poc.html" ]; then
    echo "Error: template_poc.html not found!"
    exit 1
fi

# Create a copy of the template
cp template_poc.html index_poc.html

# Function to safely escape content for JavaScript
escape_content() {
    # Escape backslashes, backticks, and dollar signs
    sed -e 's/\\/\\\\/g' -e 's/`/\\`/g' -e 's/\$/\\$/g' "$1"
}

# Replace placeholders with actual file contents
if [ -f "lib_ini.sh" ]; then
    LIB_CONTENT=$(escape_content "lib_ini.sh")
    sed -i.bak "s|<!-- LIB_INI_SH_CONTENT -->|$LIB_CONTENT|g" index_poc.html
else
    echo "Warning: lib_ini.sh not found!"
fi

# Example INI files
if [ -f "examples/simple.ini" ]; then
    SIMPLE_INI_CONTENT=$(escape_content "examples/simple.ini")
    sed -i.bak "s|<!-- EXAMPLES_SIMPLE_INI_CONTENT -->|$SIMPLE_INI_CONTENT|g" index_poc.html
    sed -i.bak "s|<!-- SIMPLE_INI_CONTENT -->|$SIMPLE_INI_CONTENT|g" index_poc.html
else
    echo "Warning: examples/simple.ini not found!"
fi

if [ -f "examples/complex.ini" ]; then
    COMPLEX_INI_CONTENT=$(escape_content "examples/complex.ini")
    sed -i.bak "s|<!-- EXAMPLES_COMPLEX_INI_CONTENT -->|$COMPLEX_INI_CONTENT|g" index_poc.html
    sed -i.bak "s|<!-- COMPLEX_INI_CONTENT -->|$COMPLEX_INI_CONTENT|g" index_poc.html
else
    echo "Warning: examples/complex.ini not found!"
fi

if [ -f "examples/empty.ini" ]; then
    EMPTY_INI_CONTENT=$(escape_content "examples/empty.ini")
    sed -i.bak "s|<!-- EXAMPLES_EMPTY_INI_CONTENT -->|$EMPTY_INI_CONTENT|g" index_poc.html
    sed -i.bak "s|<!-- EMPTY_INI_CONTENT -->|$EMPTY_INI_CONTENT|g" index_poc.html
else
    echo "Warning: examples/empty.ini not found!"
fi

if [ -f "examples/basic_usage.sh" ]; then
    BASIC_USAGE_SH_CONTENT=$(escape_content "examples/basic_usage.sh")
    sed -i.bak "s|<!-- EXAMPLES_BASIC_USAGE_SH_CONTENT -->|$BASIC_USAGE_SH_CONTENT|g" index_poc.html
else
    echo "Warning: examples/basic_usage.sh not found!"
fi

# Demo script
if [ -f "examples/demo.sh" ]; then
    RUN_DEMO_SH_CONTENT=$(escape_content "examples/demo.sh")
    sed -i.bak "s|<!-- RUN_DEMO_SH_CONTENT -->|$RUN_DEMO_SH_CONTENT|g" index_poc.html
else
    # Create a default demo script if none exists
    RUN_DEMO_SH_CONTENT='#!/bin/bash
# Demo script for bash-ini-parser

# Source the library
source ./lib_ini.sh

echo "=== Bash INI Parser Demo ==="
echo

# Create a new INI file
CONFIG_FILE="config.ini"
echo "Creating a new INI file: $CONFIG_FILE"
ini_add_section "$CONFIG_FILE" "app"
ini_write "$CONFIG_FILE" "app" "name" "My Application"
ini_write "$CONFIG_FILE" "app" "version" "1.0.0"

# Read values
echo
echo "Reading values:"
app_name=$(ini_read "$CONFIG_FILE" "app" "name")
echo "App name: $app_name"
app_version=$(ini_read "$CONFIG_FILE" "app" "version")
echo "App version: $app_version"

# List sections
echo
echo "Listing sections:"
ini_list_sections "$CONFIG_FILE" | while read section; do
    echo "- $section"
done

# List keys in a section
echo
echo "Listing keys in '"'"'app'"'"' section:"
ini_list_keys "$CONFIG_FILE" "app" | while read key; do
    echo "- $key"
done

# Write array values
echo 
echo "Writing array of supported formats..."
ini_write_array "$CONFIG_FILE" "app" "supported_formats" "jpg" "png" "gif"

# Read array values
echo
echo "Reading array values:"
ini_read_array "$CONFIG_FILE" "app" "supported_formats" | while read format; do
    echo "- $format"
done

echo
echo "Demo completed successfully!"'
    
    # Escape the content
    RUN_DEMO_SH_CONTENT=$(echo "$RUN_DEMO_SH_CONTENT" | sed -e 's/\\/\\\\/g' -e 's/`/\\`/g' -e 's/\$/\\$/g')
    sed -i.bak "s|<!-- RUN_DEMO_SH_CONTENT -->|$RUN_DEMO_SH_CONTENT|g" index_poc.html
fi

# Default config.ini
CONFIG_INI_CONTENT='[app]
name=My Application
version=1.0.0
supported_formats=jpg,png,gif'
CONFIG_INI_CONTENT=$(echo "$CONFIG_INI_CONTENT" | sed -e 's/\\/\\\\/g' -e 's/`/\\`/g' -e 's/\$/\\$/g')
sed -i.bak "s|<!-- CONFIG_INI_CONTENT -->|$CONFIG_INI_CONTENT|g" index_poc.html

# Clean up backup files
rm -f index_poc.html.bak

echo "Build complete! index_poc.html has been generated."
echo "All repository files have been embedded and lib_ini.sh is pre-loaded." 