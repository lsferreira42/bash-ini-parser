#!/bin/bash
# ==============================================================================
# Bash INI Parser Library
# ==============================================================================
# A lightweight library for manipulating INI configuration files in Bash scripts
#
# Author: Leandro Ferreira (https://leandrosf.com)
# Version: 0.0.1
# License: BSD
# GitHub: https://github.com/lsferreira42
# ==============================================================================

# Configuration
# These variables can be overridden by setting environment variables with the same name
# For example: export INI_DEBUG=1 before sourcing this library
INI_DEBUG=${INI_DEBUG:-0} # Set to 1 to enable debug messages
INI_STRICT=${INI_STRICT:-0} # Set to 1 for strict validation of section/key names
INI_ALLOW_EMPTY_VALUES=${INI_ALLOW_EMPTY_VALUES:-1} # Set to 1 to allow empty values
INI_ALLOW_SPACES_IN_NAMES=${INI_ALLOW_SPACES_IN_NAMES:-1} # Set to 1 to allow spaces in section/key names

# ==============================================================================
# Utility Functions
# ==============================================================================

# Print debug messages
function ini_debug() {
    if [ "${INI_DEBUG}" -eq 1 ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Print error messages
function ini_error() {
    echo "[ERROR] $1" >&2
}

# Validate section name
function ini_validate_section_name() {
    local section="$1"
    
    if [ -z "$section" ]; then
        ini_error "Section name cannot be empty"
        return 1
    fi
    
    if [ "${INI_STRICT}" -eq 1 ]; then
        # Check for illegal characters in section name
        if [[ "$section" =~ [\[\]\=] ]]; then
            ini_error "Section name contains illegal characters: $section"
            return 1
        fi
    fi
    
    if [ "${INI_ALLOW_SPACES_IN_NAMES}" -eq 0 ] && [[ "$section" =~ [[:space:]] ]]; then
        ini_error "Section name contains spaces: $section"
        return 1
    fi
    
    return 0
}

# Validate key name
function ini_validate_key_name() {
    local key="$1"
    
    if [ -z "$key" ]; then
        ini_error "Key name cannot be empty"
        return 1
    fi
    
    if [ "${INI_STRICT}" -eq 1 ]; then
        # Check for illegal characters in key name
        if [[ "$key" =~ [\[\]\=] ]]; then
            ini_error "Key name contains illegal characters: $key"
            return 1
        fi
    fi
    
    if [ "${INI_ALLOW_SPACES_IN_NAMES}" -eq 0 ] && [[ "$key" =~ [[:space:]] ]]; then
        ini_error "Key name contains spaces: $key"
        return 1
    fi
    
    return 0
}

# Create a secure temporary file
function ini_create_temp_file() {
    mktemp "${TMPDIR:-/tmp}/ini_XXXXXXXXXX"
}

# Trim whitespace from start and end of a string
function ini_trim() {
    local var="$*"
    # Remove leading whitespace
    var="${var#"${var%%[![:space:]]*}"}"
    # Remove trailing whitespace
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# Escape special characters in a string for regex matching
function ini_escape_for_regex() {
    echo "$1" | sed -e 's/[]\/()$*.^|[]/\\&/g'
}

# ==============================================================================
# File Operations
# ==============================================================================

function ini_check_file() {
    local file="$1"
    
    # Check if file parameter is provided
    if [ -z "$file" ]; then
        ini_error "File path is required"
        return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        ini_debug "File does not exist, attempting to create: $file"
        # Create directory if it doesn't exist
        local dir
        dir=$(dirname "$file")
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" 2>/dev/null || {
                ini_error "Could not create directory: $dir"
                return 1
            }
        fi
        
        # Create the file
        if ! touch "$file" 2>/dev/null; then
            ini_error "Could not create file: $file"
            return 1
        fi
        ini_debug "File created successfully: $file"
    fi
    
    # Check if file is writable
    if [ ! -w "$file" ]; then
        ini_error "File is not writable: $file"
        return 1
    fi
    
    return 0
}

# ==============================================================================
# Core Functions
# ==============================================================================

function ini_read() {
    local file="$1"
    local section="$2"
    local key="$3"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        ini_error "ini_read: Missing required parameters"
        return 1
    fi
    
    # Validate section and key names only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
        ini_validate_key_name "$key" || return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        ini_error "File not found: $file"
        return 1
    fi
    
    # Escape section and key for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    local escaped_key
    escaped_key=$(ini_escape_for_regex "$key")
    
    local section_pattern="^\[$escaped_section\]"
    local in_section=0
    
    ini_debug "Reading key '$key' from section '$section' in file: $file"
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]]; then
            continue
        fi
        
        # Check for section
        if [[ "$line" =~ $section_pattern ]]; then
            in_section=1
            ini_debug "Found section: $section"
            continue
        fi
        
        # Check if we've moved to a different section
        if [[ $in_section -eq 1 && "$line" =~ ^\[[^]]+\] ]]; then
            ini_debug "Reached end of section without finding key"
            return 1
        fi
        
        # Check for key in the current section
        if [[ $in_section -eq 1 ]]; then
            local key_pattern="^[[:space:]]*${escaped_key}[[:space:]]*="
            if [[ "$line" =~ $key_pattern ]]; then
                local value="${line#*=}"
                # Trim whitespace
                value=$(ini_trim "$value")
                
                # Check for quoted values
                if [[ "$value" =~ ^\"(.*)\"$ ]]; then
                    # Remove the quotes
                    value="${BASH_REMATCH[1]}"
                    # Handle escaped quotes within the value
                    value="${value//\\\"/\"}"
                fi
                
                ini_debug "Found value: $value"
                echo "$value"
                return 0
            fi
        fi
    done < "$file"
    
    ini_debug "Key not found: $key in section: $section"
    return 1
}

function ini_list_sections() {
    local file="$1"
    
    # Validate parameters
    if [ -z "$file" ]; then
        ini_error "ini_list_sections: Missing file parameter"
        return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        ini_error "File not found: $file"
        return 1
    fi
    
    ini_debug "Listing sections in file: $file"
    
    # Extract section names
    grep -o '^\[[^]]*\]' "$file" 2>/dev/null | sed 's/^\[\(.*\)\]$/\1/'
    return 0
}

function ini_list_keys() {
    local file="$1"
    local section="$2"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ]; then
        ini_error "ini_list_keys: Missing required parameters"
        return 1
    fi
    
    # Validate section name only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        ini_error "File not found: $file"
        return 1
    fi
    
    # Escape section for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    local section_pattern="^\[$escaped_section\]"
    local in_section=0
    
    ini_debug "Listing keys in section '$section' in file: $file"
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*[#\;] ]]; then
            continue
        fi
        
        # Check for section
        if [[ "$line" =~ $section_pattern ]]; then
            in_section=1
            ini_debug "Found section: $section"
            continue
        fi
        
        # Check if we've moved to a different section
        if [[ $in_section -eq 1 && "$line" =~ ^\[[^]]+\] ]]; then
            break
        fi
        
        # Extract key name from current section
        if [[ $in_section -eq 1 && "$line" =~ ^[[:space:]]*[^=]+= ]]; then
            local key="${line%%=*}"
            key=$(ini_trim "$key")
            ini_debug "Found key: $key"
            echo "$key"
        fi
    done < "$file"
    
    return 0
}

function ini_section_exists() {
    local file="$1"
    local section="$2"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ]; then
        ini_error "ini_section_exists: Missing required parameters"
        return 1
    fi
    
    # Validate section name only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        ini_debug "File not found: $file"
        return 1
    fi
    
    # Escape section for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    
    ini_debug "Checking if section '$section' exists in file: $file"
    
    # Check if section exists
    grep -q "^\[$escaped_section\]" "$file"
    local result=$?
    
    if [ $result -eq 0 ]; then
        ini_debug "Section found: $section"
    else
        ini_debug "Section not found: $section"
    fi
    
    return $result
}

function ini_add_section() {
    local file="$1"
    local section="$2"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ]; then
        ini_error "ini_add_section: Missing required parameters"
        return 1
    fi
    
    # Validate section name only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
    fi
    
    # Check and create file if needed
    ini_check_file "$file" || return 1
    
    # Check if section already exists
    if ini_section_exists "$file" "$section"; then
        ini_debug "Section already exists: $section"
        return 0
    fi
    
    ini_debug "Adding section '$section' to file: $file"
    
    # Add a newline if file is not empty
    if [ -s "$file" ]; then
        echo "" >> "$file"
    fi
    
    # Add the section
    echo "[$section]" >> "$file"
    
    return 0
}

function ini_write() {
    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        ini_error "ini_write: Missing required parameters"
        return 1
    fi
    
    # Validate section and key names only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
        ini_validate_key_name "$key" || return 1
    fi
    
    # Check for empty value if not allowed
    if [ -z "$value" ] && [ "${INI_ALLOW_EMPTY_VALUES}" -eq 0 ]; then
        ini_error "Empty values are not allowed"
        return 1
    fi
    
    # Check and create file if needed
    ini_check_file "$file" || return 1
    
    # Create section if it doesn't exist
    ini_add_section "$file" "$section" || return 1
    
    # Escape section and key for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    local escaped_key
    escaped_key=$(ini_escape_for_regex "$key")
    
    local section_pattern="^\[$escaped_section\]"
    local key_pattern="^[[:space:]]*${escaped_key}[[:space:]]*="
    local in_section=0
    local found_key=0
    local temp_file
    temp_file=$(ini_create_temp_file)
    
    ini_debug "Writing key '$key' with value '$value' to section '$section' in file: $file"
    
    # Special handling for values with quotes or special characters
    if [ "${INI_STRICT}" -eq 1 ] && [[ "$value" =~ [[:space:]\"\'\`\&\|\<\>\;\$] ]]; then
        value="\"${value//\"/\\\"}\""
        ini_debug "Value contains special characters, quoting: $value"
    fi
    
    # Process the file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        # Check for section
        if [[ "$line" =~ $section_pattern ]]; then
            in_section=1
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # Check if we've moved to a different section
        if [[ $in_section -eq 1 && "$line" =~ ^\[[^]]+\] ]]; then
            # Add the key-value pair if we haven't found it yet
            if [ $found_key -eq 0 ]; then
                echo "$key=$value" >> "$temp_file"
                found_key=1
            fi
            in_section=0
        fi
        
        # Update the key if it exists in the current section
        if [[ $in_section -eq 1 && "$line" =~ $key_pattern ]]; then
            echo "$key=$value" >> "$temp_file"
            found_key=1
            continue
        fi
        
        # Write the line to the temp file
        echo "$line" >> "$temp_file"
    done < "$file"
    
    # Add the key-value pair if we're still in the section and haven't found it
    if [ $in_section -eq 1 ] && [ $found_key -eq 0 ]; then
        echo "$key=$value" >> "$temp_file"
    fi
    
    # Use atomic operation to replace the original file
    mv "$temp_file" "$file"
    
    ini_debug "Successfully wrote key '$key' with value '$value' to section '$section'"
    return 0
}

function ini_remove_section() {
    local file="$1"
    local section="$2"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ]; then
        ini_error "ini_remove_section: Missing required parameters"
        return 1
    fi
    
    # Validate section name only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        ini_error "File not found: $file"
        return 1
    fi
    
    # Escape section for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    local section_pattern="^\[$escaped_section\]"
    local in_section=0
    local temp_file
    temp_file=$(ini_create_temp_file)
    
    ini_debug "Removing section '$section' from file: $file"
    
    # Process the file line by line
    while IFS= read -r line; do
        # Check for section
        if [[ "$line" =~ $section_pattern ]]; then
            in_section=1
            continue
        fi
        
        # Check if we've moved to a different section
        if [[ $in_section -eq 1 && "$line" =~ ^\[[^]]+\] ]]; then
            in_section=0
        fi
        
        # Write the line to the temp file if not in the section to be removed
        if [ $in_section -eq 0 ]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$file"
    
    # Use atomic operation to replace the original file
    mv "$temp_file" "$file"
    
    ini_debug "Successfully removed section '$section'"
    return 0
}

function ini_remove_key() {
    local file="$1"
    local section="$2"
    local key="$3"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        ini_error "ini_remove_key: Missing required parameters"
        return 1
    fi
    
    # Validate section and key names only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
        ini_validate_key_name "$key" || return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        ini_error "File not found: $file"
        return 1
    fi
    
    # Escape section and key for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    local escaped_key
    escaped_key=$(ini_escape_for_regex "$key")
    
    local section_pattern="^\[$escaped_section\]"
    local key_pattern="^[[:space:]]*${escaped_key}[[:space:]]*="
    local in_section=0
    local temp_file
    temp_file=$(ini_create_temp_file)
    
    ini_debug "Removing key '$key' from section '$section' in file: $file"
    
    # Process the file line by line
    while IFS= read -r line; do
        # Check for section
        if [[ "$line" =~ $section_pattern ]]; then
            in_section=1
            echo "$line" >> "$temp_file"
            continue
        fi
        
        # Check if we've moved to a different section
        if [[ $in_section -eq 1 && "$line" =~ ^\[[^]]+\] ]]; then
            in_section=0
        fi
        
        # Skip the key to be removed
        if [[ $in_section -eq 1 && "$line" =~ $key_pattern ]]; then
            continue
        fi
        
        # Write the line to the temp file
        echo "$line" >> "$temp_file"
    done < "$file"
    
    # Use atomic operation to replace the original file
    mv "$temp_file" "$file"
    
    ini_debug "Successfully removed key '$key' from section '$section'"
    return 0
}

# ==============================================================================
# Extended Functions
# ==============================================================================

function ini_get_or_default() {
    local file="$1"
    local section="$2"
    local key="$3"
    local default_value="$4"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        ini_error "ini_get_or_default: Missing required parameters"
        return 1
    fi
    
    # Try to read the value
    local value
    value=$(ini_read "$file" "$section" "$key" 2>/dev/null)
    local result=$?
    
    # Return the value or default
    if [ $result -eq 0 ]; then
        echo "$value"
    else
        echo "$default_value"
    fi
    
    return 0
}

function ini_import() {
    local source_file="$1"
    local target_file="$2"
    local import_sections=("${@:3}")
    
    # Validate parameters
    if [ -z "$source_file" ] || [ -z "$target_file" ]; then
        ini_error "ini_import: Missing required parameters"
        return 1
    fi
    
    # Check if source file exists
    if [ ! -f "$source_file" ]; then
        ini_error "Source file not found: $source_file"
        return 1
    fi
    
    # Check and create target file if needed
    ini_check_file "$target_file" || return 1
    
    ini_debug "Importing from '$source_file' to '$target_file'"
    
    # Get sections from source file
    local sections
    sections=$(ini_list_sections "$source_file")
    
    # Loop through sections
    for section in $sections; do
        # Skip if specific sections are provided and this one is not in the list
        if [ ${#import_sections[@]} -gt 0 ] && ! [[ ${import_sections[*]} =~ $section ]]; then
            ini_debug "Skipping section: $section"
            continue
        fi
        
        ini_debug "Importing section: $section"
        
        # Add the section to the target file
        ini_add_section "$target_file" "$section"
        
        # Get keys in this section
        local keys
        keys=$(ini_list_keys "$source_file" "$section")
        
        # Loop through keys
        for key in $keys; do
            # Read the value and write it to the target file
            local value
            value=$(ini_read "$source_file" "$section" "$key")
            ini_write "$target_file" "$section" "$key" "$value"
        done
    done
    
    ini_debug "Import completed successfully"
    return 0
}

function ini_to_env() {
    local file="$1"
    local prefix="$2"
    local section="$3"
    
    # Validate parameters
    if [ -z "$file" ]; then
        ini_error "ini_to_env: Missing file parameter"
        return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        ini_error "File not found: $file"
        return 1
    fi
    
    ini_debug "Exporting INI values to environment variables with prefix: $prefix"
    
    # If section is specified, only export keys from that section
    if [ -n "$section" ]; then
        if [ "${INI_STRICT}" -eq 1 ]; then
            ini_validate_section_name "$section" || return 1
        fi
        
        local keys
        keys=$(ini_list_keys "$file" "$section")
        
        for key in $keys; do
            local value
            value=$(ini_read "$file" "$section" "$key")
            
            # Export the variable with the given prefix
            if [ -n "$prefix" ]; then
                export "${prefix}_${section}_${key}=${value}"
            else
                export "${section}_${key}=${value}"
            fi
        done
    else
        # Export keys from all sections
        local sections
        sections=$(ini_list_sections "$file")
        
        for section in $sections; do
            local keys
            keys=$(ini_list_keys "$file" "$section")
            
            for key in $keys; do
                local value
                value=$(ini_read "$file" "$section" "$key")
                
                # Export the variable with the given prefix
                if [ -n "$prefix" ]; then
                    export "${prefix}_${section}_${key}=${value}"
                else
                    export "${section}_${key}=${value}"
                fi
            done
        done
    fi
    
    ini_debug "Environment variables set successfully"
    return 0
}

function ini_key_exists() {
    local file="$1"
    local section="$2"
    local key="$3"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        ini_error "ini_key_exists: Missing required parameters"
        return 1
    fi
    
    # Validate section and key names only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
        ini_validate_key_name "$key" || return 1
    fi
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        ini_debug "File not found: $file"
        return 1
    fi
    
    # First check if section exists
    if ! ini_section_exists "$file" "$section"; then
        ini_debug "Section not found: $section"
        return 1
    fi
    
    # Check if key exists by trying to read it
    if ini_read "$file" "$section" "$key" >/dev/null 2>&1; then
        ini_debug "Key found: $key in section: $section"
        return 0
    else
        ini_debug "Key not found: $key in section: $section"
        return 1
    fi
}

# ==============================================================================
# Array Functions
# ==============================================================================

function ini_read_array() {
    local file="$1"
    local section="$2"
    local key="$3"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        ini_error "ini_read_array: Missing required parameters"
        return 1
    fi
    
    # Read the value
    local value
    value=$(ini_read "$file" "$section" "$key") || return 1
    
    # Split the array by commas
    # We need to handle quoted values properly
    local -a result=()
    local in_quotes=0
    local current_item=""
    
    for (( i=0; i<${#value}; i++ )); do
        local char="${value:$i:1}"
        
        # Handle quotes
        if [ "$char" = '"' ]; then
# shellcheck disable=SC1003
            # Check if the quote is escaped
            if [ $i -gt 0 ] && [ "${value:$((i-1)):1}" = "\\" ]; then
                # It's an escaped quote, keep it
                current_item="${current_item:0:-1}$char"
            else
                # Toggle quote state
                in_quotes=$((1 - in_quotes))
            fi
        # Handle comma separator
        elif [ "$char" = ',' ] && [ $in_quotes -eq 0 ]; then
            # End of an item
            result+=("$(ini_trim "$current_item")")
            current_item=""
        else
            # Add character to current item
            current_item="$current_item$char"
        fi
    done
    
    # Add the last item
    if [ -n "$current_item" ] || [ ${#result[@]} -gt 0 ]; then
        result+=("$(ini_trim "$current_item")")
    fi
    
    # Output the array items, one per line
    for item in "${result[@]}"; do
        echo "$item"
    done
    
    return 0
}

function ini_write_array() {
    local file="$1"
    local section="$2"
    local key="$3"
    shift 3
    local -a array_values=("$@")
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$key" ]; then
        ini_error "ini_write_array: Missing required parameters"
        return 1
    fi
    
    # Process array values and handle quoting
    local array_string=""
    local first=1
    
    for value in "${array_values[@]}"; do
        # Add comma separator if not the first item
        if [ $first -eq 0 ]; then
            array_string="$array_string,"
        else
            first=0
        fi
        
        # Quote values with spaces or special characters
        if [[ "$value" =~ [[:space:],\"] ]]; then
            # Escape quotes
            value="${value//\"/\\\"}"
            array_string="$array_string\"$value\""
        else
            array_string="$array_string$value"
        fi
    done
    
    # Write the array string to the ini file
    ini_write "$file" "$section" "$key" "$array_string"
    return $?
}

# Load additional modules if defined
if [ -n "${INI_MODULES_DIR:-}" ] && [ -d "${INI_MODULES_DIR}" ]; then
    for module in "${INI_MODULES_DIR}"/*.sh; do
        if [ -f "$module" ] && [ -r "$module" ]; then
            # shellcheck disable=SC1090,SC1091
            source "$module"
        fi
    done
fi