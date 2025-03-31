# Bash INI Parser

![Build](https://github.com/lsferreira42/bash-ini-parser/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/github/license/lsferreira42/bash-ini-parser.svg)
![Last Commit](https://img.shields.io/github/last-commit/lsferreira42/bash-ini-parser.svg)
![Stars](https://img.shields.io/github/stars/lsferreira42/bash-ini-parser.svg)
![Issues](https://img.shields.io/github/issues/lsferreira42/bash-ini-parser.svg)

A robust shell script library for parsing and manipulating INI configuration files in Bash.

## Try It Online

You can try the Bash INI Parser directly in your browser through our interactive web demo. The demo provides a terminal environment with pre-loaded example files so you can test the library without installation.

**[Try Bash INI Parser Online](https://lsferreira42.github.io/bash-ini-parser/)**

## Features

- **Read and write** values from/to INI files
- **List sections and keys** in INI files
- **Add, update, and remove** sections and keys
- **Supports complex values** including quotes, spaces, and special characters
- **Array support** for storing multiple values
- **Import/export functionality** between files and environment variables
- **Extensive error handling** with detailed error messages
- **Debug mode** for troubleshooting
- **Configurable behavior** through environment variables
- **Backwards compatible** with previous versions

## Installation

Simply include the `lib_ini.sh` script in your project and source it in your shell scripts:

```bash
source /path/to/lib_ini.sh
```

## Basic Usage

```bash
#!/bin/bash
source ./lib_ini.sh

# Create a new INI file with sections and keys
CONFIG_FILE="config.ini"
ini_add_section "$CONFIG_FILE" "app"
ini_write "$CONFIG_FILE" "app" "name" "My Application"
ini_write "$CONFIG_FILE" "app" "version" "1.0.0"

# Read values
app_name=$(ini_read "$CONFIG_FILE" "app" "name")
echo "App name: $app_name"

# List sections and keys
echo "Available sections:"
ini_list_sections "$CONFIG_FILE" | while read section; do
    echo "- $section"
    echo "  Keys:"
    ini_list_keys "$CONFIG_FILE" "$section" | while read key; do
        value=$(ini_read "$CONFIG_FILE" "$section" "$key")
        echo "  - $key = $value"
    done
done

# Remove a key
ini_remove_key "$CONFIG_FILE" "app" "name"

# Remove a section
ini_remove_section "$CONFIG_FILE" "app"
```

## Advanced Features

### Array Support

```bash
# Write array values
ini_write_array "$CONFIG_FILE" "app" "supported_formats" "jpg" "png" "gif"

# Read array values
formats=$(ini_read_array "$CONFIG_FILE" "app" "supported_formats")
for format in $formats; do
    echo "Format: $format"
done
```

### Default Values

```bash
# Get a value or use a default if not found
timeout=$(ini_get_or_default "$CONFIG_FILE" "app" "timeout" "30")
```

### Environment Variables Export

```bash
# Export all INI values to environment variables with a prefix
ini_to_env "$CONFIG_FILE" "CFG"
echo "App name from env: $CFG_app_name"

# Export only one section
ini_to_env "$CONFIG_FILE" "CFG" "database"
```

### File Import

```bash
# Import all values from one INI file to another
ini_import "defaults.ini" "config.ini"

# Import only specific sections
ini_import "defaults.ini" "config.ini" "section1" "section2"
```

### Key Existence Check

```bash
if ini_key_exists "config.ini" "app" "version"; then
    echo "The key exists"
fi
```

## Configuration Options

The library's behavior can be customized by setting these variables either directly in your script after sourcing the library or as environment variables before sourcing the library:

```bash
# Method 1: Set in your script after sourcing
source ./lib_ini.sh
INI_DEBUG=1

# Method 2: Set as environment variables before sourcing
export INI_DEBUG=1
source ./lib_ini.sh
```

Available configuration options:

```bash
# Enable debug mode to see detailed operations
INI_DEBUG=1

# Enable strict validation of section and key names
INI_STRICT=1

# Allow empty values
INI_ALLOW_EMPTY_VALUES=1

# Allow spaces in section and key names
INI_ALLOW_SPACES_IN_NAMES=1
```

## Library Enhancements

### Security Improvements

- **Input validation** for all parameters
- **Secure regex handling** with proper escaping of special characters
- **Temporary file security** to prevent data corruption
- **File permission checks** to ensure proper access rights
- **Automatic directory creation** when needed

### Core Function Enhancements

#### File Operations
- `ini_check_file` automatically creates directories and verifies permissions
- Atomic write operations to prevent file corruption during updates

#### Reading and Writing
- Support for quoted values and special characters
- Better handling of complex strings
- Robust error detection and reporting

#### Utility Functions
- `ini_debug` - Displays debug messages when debug mode is enabled
- `ini_error` - Standardized error message format
- `ini_validate_section_name` and `ini_validate_key_name` - Validate input data
- `ini_create_temp_file` - Creates temporary files securely
- `ini_trim` - Removes whitespace from strings
- `ini_escape_for_regex` - Properly escapes special characters

### Advanced Usage Examples

#### Working with Multiple Files

```bash
# Import default settings, then override with user settings
ini_import "defaults.ini" "config.ini"
ini_import "user_prefs.ini" "config.ini"

# Copy specific sections between files
ini_import "source.ini" "target.ini" "section1" "section2"
```

#### Integration with Database Scripts

```bash
# Load database configuration into environment variables
ini_to_env "database.ini" "DB"

# Use in database commands
mysql -h "$DB_mysql_host" -u "$DB_mysql_user" -p"$DB_mysql_password" "$DB_mysql_database"
```

#### Array Manipulation

```bash
# Store a list of roles in an array
ini_write_array "config.ini" "permissions" "roles" "admin" "user" "guest"

# Read and process array values
roles=$(ini_read_array "config.ini" "permissions" "roles")
for role in $roles; do
    echo "Processing role: $role"
    # Additional processing...
done
```

## Examples

Check the `examples` directory for complete usage examples:

- `basic_usage.sh`: Demonstrates core functionality
- `advanced_usage.sh`: Shows advanced features


## License

This project is licensed under the BSD License, a permissive free software license with minimal restrictions on the use and distribution of covered software.

## Author

- **Leandro Ferreira**
- Website: [leandrosf.com](https://leandrosf.com)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 