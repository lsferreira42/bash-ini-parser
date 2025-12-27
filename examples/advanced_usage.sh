#!/bin/bash
# Advanced usage example for the improved lib_ini.sh library

# Source the library
# shellcheck disable=SC1091
source ../lib_ini.sh

# Enable debug mode to see what's happening
export INI_DEBUG=1
echo "Debug mode enabled, you will see detailed information about operations"
echo

# Create a test configuration file
echo "Creating a test configuration file 'config.ini'"
CONFIG_FILE="config.ini"

# Make sure we start with a clean file
rm -f "$CONFIG_FILE"

# Basic operations
echo "=== Basic Operations ==="
ini_add_section "$CONFIG_FILE" "app"
ini_write "$CONFIG_FILE" "app" "name" "My Advanced App"
ini_write "$CONFIG_FILE" "app" "version" "2.0.0"
ini_write "$CONFIG_FILE" "app" "debug" "false"

ini_add_section "$CONFIG_FILE" "database"
ini_write "$CONFIG_FILE" "database" "host" "localhost"
ini_write "$CONFIG_FILE" "database" "port" "3306"
ini_write "$CONFIG_FILE" "database" "user" "dbuser"
ini_write "$CONFIG_FILE" "database" "password" "s3cr3t"

echo "Reading a basic value:"
app_name=$(ini_read "$CONFIG_FILE" "app" "name")
echo "App name: $app_name"
echo

# Working with default values
echo "=== Default Values ==="
echo "Reading a value with default (exists):"
debug=$(ini_get_or_default "$CONFIG_FILE" "app" "debug" "true")
echo "Debug: $debug"

echo "Reading a value with default (doesn't exist):"
timeout=$(ini_get_or_default "$CONFIG_FILE" "app" "timeout" "30")
echo "Timeout: $timeout"
echo

# Working with arrays
echo "=== Array Support ==="
echo "Writing array values:"
ini_write_array "$CONFIG_FILE" "app" "supported_formats" "jpg" "png" "gif" "svg"
echo "Reading array values:"
formats=$(ini_read_array "$CONFIG_FILE" "app" "supported_formats")
echo "Supported formats:"
for format in $formats; do
    echo "  - $format"
done
echo

# Complex values with spaces and special characters
echo "=== Complex Values ==="
ini_write "$CONFIG_FILE" "app" "description" "This is a complex description with spaces and special characters: !@#$%^&*()"
ini_write "$CONFIG_FILE" "app" "welcome_message" "Welcome to \"My App\""
ini_write "$CONFIG_FILE" "paths" "data_directory" "/path/with spaces/data"

echo "Reading complex values:"
description=$(ini_read "$CONFIG_FILE" "app" "description")
echo "Description: $description"
message=$(ini_read "$CONFIG_FILE" "app" "welcome_message")
echo "Welcome message: $message"
echo

# Export to environment variables
echo "=== Environment Variables ==="
ini_to_env "$CONFIG_FILE" "CFG"
echo "Exported values to environment variables with prefix 'CFG'"
# shellcheck disable=SC2154
echo "Database host: $CFG_database_host"
# shellcheck disable=SC2154
echo "Database port: $CFG_database_port"
# shellcheck disable=SC2154
echo "App name: $CFG_app_name"
echo

# Import from another file
echo "=== File Import ==="
echo "Creating another file 'defaults.ini'"
DEFAULTS_FILE="defaults.ini"
rm -f "$DEFAULTS_FILE"

ini_add_section "$DEFAULTS_FILE" "logging"
ini_write "$DEFAULTS_FILE" "logging" "level" "info"
ini_write "$DEFAULTS_FILE" "logging" "file" "/var/log/app.log"
ini_write "$DEFAULTS_FILE" "logging" "max_size" "10M"

ini_add_section "$DEFAULTS_FILE" "security"
ini_write "$DEFAULTS_FILE" "security" "enable_2fa" "true"
ini_write "$DEFAULTS_FILE" "security" "password_expiry_days" "90"

echo "Importing from defaults.ini to config.ini"
ini_import "$DEFAULTS_FILE" "$CONFIG_FILE"

echo "Reading imported values:"
log_level=$(ini_read "$CONFIG_FILE" "logging" "level")
echo "Log level: $log_level"
enable_2fa=$(ini_read "$CONFIG_FILE" "security" "enable_2fa")
echo "2FA enabled: $enable_2fa"
echo

# Check existence
echo "=== Key Existence Check ==="
if ini_key_exists "$CONFIG_FILE" "app" "version"; then
    echo "Key 'version' exists in section 'app'"
fi

if ! ini_key_exists "$CONFIG_FILE" "app" "non_existent_key"; then
    echo "Key 'non_existent_key' does not exist in section 'app'"
fi
echo

# Remove operations
echo "=== Remove Operations ==="
echo "Removing key 'debug' from section 'app'"
ini_remove_key "$CONFIG_FILE" "app" "debug"

echo "Removing section 'security'"
ini_remove_section "$CONFIG_FILE" "security"

echo "Final file contents:"
cat "$CONFIG_FILE"
echo

echo "All operations completed successfully!" 