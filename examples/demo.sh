#!/bin/bash
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
echo "Listing keys in 'app' section:"
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
echo "Demo completed successfully!"
