#!/bin/bash
# Basic usage example for the Bash INI Parser library

# Load the library
# shellcheck disable=SC1091
source ../lib_ini.sh

echo "Simple INI file operations example"
echo

# Set the configuration file
CONFIG_FILE="simple_config.ini"
echo "Creating a test configuration file '$CONFIG_FILE'"

# Make sure we start with a clean file
rm -f "$CONFIG_FILE"

# Create sections and add values
echo "1. Creating sections and adding values"
ini_add_section "$CONFIG_FILE" "general"
ini_write "$CONFIG_FILE" "general" "app_name" "My App"
ini_write "$CONFIG_FILE" "general" "version" "1.0.0"

ini_add_section "$CONFIG_FILE" "user"
ini_write "$CONFIG_FILE" "user" "name" "John Doe"
ini_write "$CONFIG_FILE" "user" "email" "john@example.com"

# Display the file contents
echo "File contents after writing:"
cat "$CONFIG_FILE"
echo

# Read values
echo "2. Reading values"
app_name=$(ini_read "$CONFIG_FILE" "general" "app_name")
version=$(ini_read "$CONFIG_FILE" "general" "version")
user_name=$(ini_read "$CONFIG_FILE" "user" "name")

echo "App name: $app_name"
echo "Version: $version"
echo "User name: $user_name"
echo

# List sections and keys
echo "3. Listing sections and keys"
echo "Sections in the file:"
ini_list_sections "$CONFIG_FILE" | while read -r section; do
    echo "- $section"
done

echo "Keys in 'general' section:"
ini_list_keys "$CONFIG_FILE" "general" | while read -r key; do
    echo "- $key"
done
echo

# Update a value
echo "4. Updating a value"
echo "Updating version to 1.1.0"
ini_write "$CONFIG_FILE" "general" "version" "1.1.0"
new_version=$(ini_read "$CONFIG_FILE" "general" "version")
echo "New version: $new_version"
echo

# Remove a key
echo "5. Removing a key"
echo "Removing the 'email' key from 'user' section"
ini_remove_key "$CONFIG_FILE" "user" "email"
echo "File contents after removing key:"
cat "$CONFIG_FILE"
echo

# Add a new section
echo "6. Adding a new section"
ini_add_section "$CONFIG_FILE" "preferences"
ini_write "$CONFIG_FILE" "preferences" "theme" "dark"
ini_write "$CONFIG_FILE" "preferences" "language" "en-US"
echo "File contents after adding section:"
cat "$CONFIG_FILE"
echo

# Remove a section
echo "7. Removing a section"
echo "Removing the 'preferences' section"
ini_remove_section "$CONFIG_FILE" "preferences"
echo "File contents after removing section:"
cat "$CONFIG_FILE"
echo

# Check if sections and keys exist
echo "8. Checking existence"
if ini_section_exists "$CONFIG_FILE" "general"; then
    echo "Section 'general' exists"
fi

if ini_key_exists "$CONFIG_FILE" "user" "name"; then
    echo "Key 'name' exists in section 'user'"
fi

if ! ini_section_exists "$CONFIG_FILE" "preferences"; then
    echo "Section 'preferences' does not exist anymore"
fi
echo

echo "Basic operations completed successfully!" 