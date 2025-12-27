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
INI_MAX_FILE_SIZE=${INI_MAX_FILE_SIZE:-10485760} # Maximum file size in bytes (default: 10MB)

# Track temporary files for cleanup
declare -a _ini_temp_files=()
declare -a _ini_lock_fds=()

# Cleanup function for temporary files
function _ini_cleanup_temp_files() {
    local file
    for file in "${_ini_temp_files[@]}"; do
        [ -f "$file" ] && rm -f "$file" 2>/dev/null
    done
    _ini_temp_files=()
}

# Cleanup function for lock file descriptors
function _ini_cleanup_locks() {
    local fd
    for fd in "${_ini_lock_fds[@]}"; do
        [ -n "$fd" ] && exec {fd}>&- 2>/dev/null || true
    done
    _ini_lock_fds=()
}

# Trap handlers for cleanup on exit/interrupt
trap '_ini_cleanup_temp_files; _ini_cleanup_locks; exit 130' INT
trap '_ini_cleanup_temp_files; _ini_cleanup_locks; exit 143' TERM
trap '_ini_cleanup_temp_files; _ini_cleanup_locks' EXIT

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
    local temp_file
    if ! temp_file=$(mktemp "${TMPDIR:-/tmp}/ini_XXXXXXXXXX" 2>/dev/null) || [ -z "$temp_file" ]; then
        ini_error "Failed to create temporary file"
        return 1
    fi
    _ini_temp_files+=("$temp_file")
    echo "$temp_file"
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

# Validate and normalize file path to prevent path traversal
function ini_validate_path() {
    local file="$1"
    
    if [ -z "$file" ]; then
        return 1
    fi
    
    # Check for path traversal attempts
    if [[ "$file" =~ \.\./ ]]; then
        ini_error "Path traversal detected: $file"
        return 1
    fi
    
    # Normalize path (resolve relative paths)
    local normalized
    if command -v realpath >/dev/null 2>&1; then
        normalized=$(realpath -m "$file" 2>/dev/null || echo "$file")
        # realpath returns absolute paths, so .. in the middle is valid (e.g., /home/../home)
        # Only reject if .. appears at the start suggesting traversal
        if [[ "$normalized" =~ ^\.\./ ]]; then
            ini_error "Invalid path after normalization: $normalized"
            return 1
        fi
    else
        # Fallback: basic normalization
        normalized="$file"
        # Remove leading ./ if present
        normalized="${normalized#./}"
        
        # Additional check: ensure path doesn't escape expected boundaries
        # Only check for .. if it's part of a path traversal pattern
        if [[ "$normalized" =~ \.\./ ]] || [[ "$normalized" =~ /\.\. ]] || [[ "$normalized" =~ ^\.\.$ ]]; then
            ini_error "Invalid path after normalization: $normalized"
            return 1
        fi
    fi
    
    return 0
}

# Resolve symlinks safely
function ini_resolve_symlink() {
    local file="$1"
    local resolved
    
    # Check if file exists (even as symlink)
    if [ ! -e "$file" ] && [ ! -L "$file" ]; then
        echo "$file"
        return 0
    fi
    
    # Check if it's a symlink
    if [ -L "$file" ]; then
        # Resolve symlink
        if command -v readlink >/dev/null 2>&1; then
            if ! resolved=$(readlink -f "$file" 2>/dev/null) || [ -z "$resolved" ]; then
                ini_error "Failed to resolve symlink: $file"
                return 1
            fi
            echo "$resolved"
            return 0
        else
            # Fallback: just return the original if readlink not available
            ini_debug "readlink not available, using original path"
            echo "$file"
            return 0
        fi
    else
        echo "$file"
        return 0
    fi
}

# Check file size
function ini_check_file_size() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        return 0  # File doesn't exist yet, size check not needed
    fi
    
    local size
    if command -v stat >/dev/null 2>&1; then
        # Try different stat syntaxes for different systems
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    else
        # Fallback: use wc -c
        size=$(wc -c < "$file" 2>/dev/null || echo "0")
    fi
    
    if [ -n "$size" ] && [ "$size" -gt "${INI_MAX_FILE_SIZE}" ]; then
        ini_error "File too large: $file (${size} bytes, max: ${INI_MAX_FILE_SIZE} bytes)"
        return 1
    fi
    
    return 0
}

# Validate environment variable name
function ini_validate_env_var_name() {
    local name="$1"
    
    if [ -z "$name" ]; then
        return 1
    fi
    
    # Nomes de variáveis devem começar com letra ou underscore
    # e conter apenas letras, números e underscores
    if [[ ! "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        return 1
    fi
    
    return 0
}

# Remove UTF-8 BOM (Byte Order Mark) from a line if present
# BOM in UTF-8 is the byte sequence EF BB BF (appears as U+FEFF)
# This function is safe to call on any line - it only removes BOM if present
function _ini_remove_bom() {
    local line="$1"
    
    # Check if line starts with UTF-8 BOM (U+FEFF = \xEF\xBB\xBF)
    # In bash, we check for the BOM character directly
    if [[ "$line" =~ ^$'\xEF\xBB\xBF' ]]; then
        # Remove BOM from the beginning
        line="${line#$'\xEF\xBB\xBF'}"
        ini_debug "Removed UTF-8 BOM from line"
    fi
    
    echo "$line"
}


# Lock file using flock
function ini_lock_file() {
    local file="$1"
    local lock_file="${file}.lock"
    local lock_fd
    local max_attempts=10
    local attempt=0
    
    # Try to create lock file
    while [ $attempt -lt $max_attempts ]; do
        if exec {lock_fd}>"$lock_file" 2>/dev/null; then
            # Try to obtain exclusive lock (timeout of 1 second per attempt)
            if flock -w 1 -x "$lock_fd" 2>/dev/null; then
                _ini_lock_fds+=("$lock_fd")
                echo "$lock_fd"
                return 0
            else
                exec {lock_fd}>&-
            fi
        fi
        attempt=$((attempt + 1))
        sleep 0.1
    done
    
    ini_error "Failed to acquire lock on file: $file (after ${max_attempts} attempts)"
    return 1
}

# Unlock file
function ini_unlock_file() {
    local lock_fd="$1"
    
    if [ -n "$lock_fd" ] && [ "$lock_fd" -ge 10 ] 2>/dev/null; then
        flock -u "$lock_fd" 2>/dev/null || true
        # Close file descriptor - use eval to handle dynamic fd
        eval "exec $lock_fd>&-" 2>/dev/null || true
    fi
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
    
    # Validate path to prevent path traversal
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks safely
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check file size if file exists
    if [ -f "$resolved_file" ]; then
        ini_check_file_size "$resolved_file" || return 1
    fi
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_debug "File does not exist, attempting to create: $resolved_file"
        # Create directory if it doesn't exist
        local dir
        dir=$(dirname "$resolved_file")
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" 2>/dev/null || {
                ini_error "Could not create directory: $dir"
                return 1
            }
        fi
        
        # Create the file
        if ! touch "$resolved_file" 2>/dev/null; then
            ini_error "Could not create file: $resolved_file"
            return 1
        fi
        ini_debug "File created successfully: $resolved_file"
    fi
    
    # Check if file is writable
    if [ ! -w "$resolved_file" ]; then
        ini_error "File is not writable: $resolved_file"
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
    
    local first_line=1
    while IFS= read -r line; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
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
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_error "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
    ini_debug "Listing sections in file: $file"
    
    # Extract section names, handling BOM on first line
    local first_line=1
    while IFS= read -r line; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
        # Check for section header
        if [[ "$line" =~ ^\[([^]]+)\] ]]; then
            echo "${BASH_REMATCH[1]}"
        fi
    done < "$file"
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
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_error "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
    # Escape section for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    local section_pattern="^\[$escaped_section\]"
    local in_section=0
    
    ini_debug "Listing keys in section '$section' in file: $file"
    
    local first_line=1
    while IFS= read -r line; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
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
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_debug "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
    # Escape section for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    
    ini_debug "Checking if section '$section' exists in file: $file"
    
    # Check if section exists, handling BOM on first line
    local first_line=1
    local found=0
    while IFS= read -r line; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
        # Check for section header
        if [[ "$line" =~ ^\[$escaped_section\] ]]; then
            found=1
            break
        fi
    done < "$file"
    
    if [ $found -eq 1 ]; then
        ini_debug "Section found: $section"
        return 0
    else
        ini_debug "Section not found: $section"
        return 1
    fi
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
    # Acquire lock for file writing
    local lock_fd
    lock_fd=$(ini_lock_file "$file") || return 1
    
    local temp_file
    temp_file=$(ini_create_temp_file) || {
        ini_unlock_file "$lock_fd"
        return 1
    }
    
    ini_debug "Writing key '$key' with value '$value' to section '$section' in file: $file"
    
    # Special handling for values with quotes or special characters
    if [ "${INI_STRICT}" -eq 1 ] && [[ "$value" =~ [[:space:]\"\'\`\&\|\<\>\;\$] ]]; then
        value="\"${value//\"/\\\"}\""
        ini_debug "Value contains special characters, quoting: $value"
    fi
    
    # Process the file line by line
    local first_line=1
    while IFS= read -r line || [ -n "$line" ]; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
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
    
    # Create backup before atomic operation
    local backup_file=""
    if [ -f "$file" ]; then
        backup_file="${file}.bak.$$"
        if ! cp "$file" "$backup_file" 2>/dev/null; then
            ini_error "Failed to create backup"
            rm -f "$temp_file"
            ini_unlock_file "$lock_fd"
            return 1
        fi
    fi
    
    # Use atomic operation to replace the original file
    if ! mv "$temp_file" "$file" 2>/dev/null; then
        ini_error "Failed to atomically replace file"
        rm -f "$temp_file"
        [ -f "$backup_file" ] && rm -f "$backup_file"
        ini_unlock_file "$lock_fd"
        return 1
    fi
    
    # Remove from temp files tracking since we successfully moved it
    local new_array=()
    for item in "${_ini_temp_files[@]}"; do
        [ "$item" != "$temp_file" ] && new_array+=("$item")
    done
    _ini_temp_files=("${new_array[@]}")
    
    # Clean up backup after successful operation
    [ -f "$backup_file" ] && rm -f "$backup_file"
    
    # Release lock
    ini_unlock_file "$lock_fd"
    
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
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_error "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
    # Acquire lock for file writing
    local lock_fd
    lock_fd=$(ini_lock_file "$file") || return 1
    
    # Escape section for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    local section_pattern="^\[$escaped_section\]"
    local in_section=0
    local temp_file
    temp_file=$(ini_create_temp_file) || {
        ini_unlock_file "$lock_fd"
        return 1
    }
    
    ini_debug "Removing section '$section' from file: $file"
    
    # Process the file line by line
    local first_line=1
    while IFS= read -r line; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
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
    
    # Create backup before atomic operation
    local backup_file=""
    if [ -f "$file" ]; then
        backup_file="${file}.bak.$$"
        if ! cp "$file" "$backup_file" 2>/dev/null; then
            ini_error "Failed to create backup"
            rm -f "$temp_file"
            ini_unlock_file "$lock_fd"
            return 1
        fi
    fi
    
    # Use atomic operation to replace the original file
    if ! mv "$temp_file" "$file" 2>/dev/null; then
        ini_error "Failed to atomically replace file"
        rm -f "$temp_file"
        [ -f "$backup_file" ] && rm -f "$backup_file"
        ini_unlock_file "$lock_fd"
        return 1
    fi
    
    # Remove from temp files tracking since we successfully moved it
    local new_array=()
    for item in "${_ini_temp_files[@]}"; do
        [ "$item" != "$temp_file" ] && new_array+=("$item")
    done
    _ini_temp_files=("${new_array[@]}")
    
    # Clean up backup after successful operation
    [ -f "$backup_file" ] && rm -f "$backup_file"
    
    # Release lock
    ini_unlock_file "$lock_fd"
    
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
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_error "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
    # Acquire lock for file writing
    local lock_fd
    lock_fd=$(ini_lock_file "$file") || return 1
    
    # Escape section and key for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    local escaped_key
    escaped_key=$(ini_escape_for_regex "$key")
    
    local section_pattern="^\[$escaped_section\]"
    local key_pattern="^[[:space:]]*${escaped_key}[[:space:]]*="
    local in_section=0
    local temp_file
    temp_file=$(ini_create_temp_file) || {
        ini_unlock_file "$lock_fd"
        return 1
    }
    
    ini_debug "Removing key '$key' from section '$section' in file: $file"
    
    # Process the file line by line
    local first_line=1
    while IFS= read -r line; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
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
    
    # Create backup before atomic operation
    local backup_file=""
    if [ -f "$file" ]; then
        backup_file="${file}.bak.$$"
        if ! cp "$file" "$backup_file" 2>/dev/null; then
            ini_error "Failed to create backup"
            rm -f "$temp_file"
            ini_unlock_file "$lock_fd"
            return 1
        fi
    fi
    
    # Use atomic operation to replace the original file
    if ! mv "$temp_file" "$file" 2>/dev/null; then
        ini_error "Failed to atomically replace file"
        rm -f "$temp_file"
        [ -f "$backup_file" ] && rm -f "$backup_file"
        ini_unlock_file "$lock_fd"
        return 1
    fi
    
    # Remove from temp files tracking since we successfully moved it
    local new_array=()
    for item in "${_ini_temp_files[@]}"; do
        [ "$item" != "$temp_file" ] && new_array+=("$item")
    done
    _ini_temp_files=("${new_array[@]}")
    
    # Clean up backup after successful operation
    [ -f "$backup_file" ] && rm -f "$backup_file"
    
    # Release lock
    ini_unlock_file "$lock_fd"
    
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
    
    # Validate paths
    ini_validate_path "$source_file" || return 1
    ini_validate_path "$target_file" || return 1
    
    # Resolve symlinks
    local resolved_source
    resolved_source=$(ini_resolve_symlink "$source_file") || return 1
    
    # Check if source file exists
    if [ ! -f "$resolved_source" ]; then
        ini_error "Source file not found: $resolved_source"
        return 1
    fi
    
    # Check source file size
    ini_check_file_size "$resolved_source" || return 1
    
    # Check if source file is readable
    if [ ! -r "$resolved_source" ]; then
        ini_error "Source file is not readable: $resolved_source"
        return 1
    fi
    
    local source_file="$resolved_source"
    
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
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_error "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
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
            
            # Build variable name
            local var_name
            if [ -n "$prefix" ]; then
                var_name="${prefix}_${section}_${key}"
            else
                var_name="${section}_${key}"
            fi
            
            # Sanitize variable name (replace invalid chars with underscore)
            var_name="${var_name//[^a-zA-Z0-9_]/_}"
            
            # Validate variable name
            if ! ini_validate_env_var_name "$var_name"; then
                ini_error "Invalid environment variable name generated: $var_name (from prefix=$prefix, section=$section, key=$key)"
                continue
            fi
            
            # Export the variable
            export "${var_name}=${value}"
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
                
                # Build variable name
                local var_name
                if [ -n "$prefix" ]; then
                    var_name="${prefix}_${section}_${key}"
                else
                    var_name="${section}_${key}"
                fi
                
                # Sanitize variable name (replace invalid chars with underscore)
                var_name="${var_name//[^a-zA-Z0-9_]/_}"
                
                # Validate variable name
                if ! ini_validate_env_var_name "$var_name"; then
                    ini_error "Invalid environment variable name generated: $var_name (from prefix=$prefix, section=$section, key=$key)"
                    continue
                fi
                
                # Export the variable
                export "${var_name}=${value}"
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
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_debug "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
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

# ==============================================================================
# Advanced Features
# ==============================================================================

function ini_validate() {
    local file="$1"
    local errors=0
    
    # Validate parameters
    if [ -z "$file" ]; then
        ini_error "ini_validate: Missing file parameter"
        return 1
    fi
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_error "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
    ini_debug "Validating INI file structure: $file"
    
    local line_num=0
    local in_section=0
    local last_section=""
    local sections_found=0
    local first_line=1
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
        line_num=$((line_num + 1))
        local trimmed_line
        trimmed_line=$(ini_trim "$line")
        
        # Skip empty lines and comments
        if [[ -z "$trimmed_line" || "$trimmed_line" =~ ^[[:space:]]*[#\;] ]]; then
            continue
        fi
        
        # Check for section header
        if [[ "$trimmed_line" =~ ^\[([^]]+)\]$ ]]; then
            in_section=1
            last_section="${BASH_REMATCH[1]}"
            sections_found=$((sections_found + 1))
            
            # Validate section name if strict mode
            if [ "${INI_STRICT}" -eq 1 ]; then
                if ! ini_validate_section_name "$last_section" >/dev/null 2>&1; then
                    ini_error "Line $line_num: Invalid section name: $last_section"
                    errors=$((errors + 1))
                fi
            fi
            continue
        fi
        
        # Check for key=value pair
        if [[ "$trimmed_line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
            if [ $in_section -eq 0 ]; then
                ini_error "Line $line_num: Key-value pair outside of section: $trimmed_line"
                errors=$((errors + 1))
            else
                local key="${BASH_REMATCH[1]}"
                key=$(ini_trim "$key")
                
                # Validate key name if strict mode
                if [ "${INI_STRICT}" -eq 1 ]; then
                    if ! ini_validate_key_name "$key" >/dev/null 2>&1; then
                        ini_error "Line $line_num: Invalid key name in section [$last_section]: $key"
                        errors=$((errors + 1))
                    fi
                fi
            fi
            continue
        fi
        
        # Invalid line format
        ini_error "Line $line_num: Invalid INI format: $trimmed_line"
        errors=$((errors + 1))
    done < "$file"
    
    if [ $errors -eq 0 ]; then
        ini_debug "File validation passed: $file ($sections_found sections)"
        return 0
    else
        ini_error "File validation failed: $file ($errors error(s) found)"
        return 1
    fi
}

function ini_get_all() {
    local file="$1"
    local section="$2"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ]; then
        ini_error "ini_get_all: Missing required parameters"
        return 1
    fi
    
    # Validate section name only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
    fi
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_error "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
    # Escape section for regex pattern
    local escaped_section
    escaped_section=$(ini_escape_for_regex "$section")
    local section_pattern="^\[$escaped_section\]"
    local in_section=0
    
    ini_debug "Getting all keys from section '$section' in file: $file"
    
    local first_line=1
    while IFS= read -r line; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
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
        
        # Extract key=value from current section
        if [[ $in_section -eq 1 && "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            key=$(ini_trim "$key")
            value=$(ini_trim "$value")
            
            # Handle quoted values
            if [[ "$value" =~ ^\"(.*)\"$ ]]; then
                value="${BASH_REMATCH[1]}"
                value="${value//\\\"/\"}"
            fi
            
            echo "${key}=${value}"
        fi
    done < "$file"
    
    return 0
}

function ini_rename_section() {
    local file="$1"
    local old_section="$2"
    local new_section="$3"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$old_section" ] || [ -z "$new_section" ]; then
        ini_error "ini_rename_section: Missing required parameters"
        return 1
    fi
    
    # Validate section names only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$old_section" || return 1
        ini_validate_section_name "$new_section" || return 1
    fi
    
    # Check if old section exists
    if ! ini_section_exists "$file" "$old_section"; then
        ini_error "Section not found: $old_section"
        return 1
    fi
    
    # Check if new section already exists
    if ini_section_exists "$file" "$new_section"; then
        ini_error "Section already exists: $new_section"
        return 1
    fi
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    local file="$resolved_file"
    
    # Acquire lock for file writing
    local lock_fd
    lock_fd=$(ini_lock_file "$file") || return 1
    
    # Escape sections for regex pattern
    local escaped_old_section
    escaped_old_section=$(ini_escape_for_regex "$old_section")
    
    local old_section_pattern="^\[$escaped_old_section\]"
    local in_section=0
    local temp_file
    temp_file=$(ini_create_temp_file) || {
        ini_unlock_file "$lock_fd"
        return 1
    }
    
    ini_debug "Renaming section '$old_section' to '$new_section' in file: $file"
    
    # Process the file line by line
    local first_line=1
    while IFS= read -r line || [ -n "$line" ]; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
        # Check for old section header
        if [[ "$line" =~ $old_section_pattern ]]; then
            in_section=1
            echo "[$new_section]" >> "$temp_file"
            continue
        fi
        
        # Check if we've moved to a different section
        if [[ $in_section -eq 1 && "$line" =~ ^\[[^]]+\] ]]; then
            in_section=0
        fi
        
        # Write the line to the temp file
        echo "$line" >> "$temp_file"
    done < "$file"
    
    # Create backup before atomic operation
    local backup_file=""
    if [ -f "$file" ]; then
        backup_file="${file}.bak.$$"
        if ! cp "$file" "$backup_file" 2>/dev/null; then
            ini_error "Failed to create backup"
            rm -f "$temp_file"
            ini_unlock_file "$lock_fd"
            return 1
        fi
    fi
    
    # Use atomic operation to replace the original file
    if ! mv "$temp_file" "$file" 2>/dev/null; then
        ini_error "Failed to atomically replace file"
        rm -f "$temp_file"
        [ -f "$backup_file" ] && rm -f "$backup_file"
        ini_unlock_file "$lock_fd"
        return 1
    fi
    
    # Remove from temp files tracking since we successfully moved it
    local new_array=()
    for item in "${_ini_temp_files[@]}"; do
        [ "$item" != "$temp_file" ] && new_array+=("$item")
    done
    _ini_temp_files=("${new_array[@]}")
    
    # Clean up backup after successful operation
    [ -f "$backup_file" ] && rm -f "$backup_file"
    
    # Release lock
    ini_unlock_file "$lock_fd"
    
    ini_debug "Successfully renamed section '$old_section' to '$new_section'"
    return 0
}

function ini_rename_key() {
    local file="$1"
    local section="$2"
    local old_key="$3"
    local new_key="$4"
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ -z "$old_key" ] || [ -z "$new_key" ]; then
        ini_error "ini_rename_key: Missing required parameters"
        return 1
    fi
    
    # Validate section and key names only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
        ini_validate_key_name "$old_key" || return 1
        ini_validate_key_name "$new_key" || return 1
    fi
    
    # Check if old key exists
    if ! ini_key_exists "$file" "$section" "$old_key"; then
        ini_error "Key not found: $old_key in section: $section"
        return 1
    fi
    
    # Check if new key already exists
    if ini_key_exists "$file" "$section" "$new_key"; then
        ini_error "Key already exists: $new_key in section: $section"
        return 1
    fi
    
    # Get the value of the old key
    local value
    value=$(ini_read "$file" "$section" "$old_key") || return 1
    
    # Remove old key and write new key with same value
    ini_remove_key "$file" "$section" "$old_key" || return 1
    ini_write "$file" "$section" "$new_key" "$value" || return 1
    
    ini_debug "Successfully renamed key '$old_key' to '$new_key' in section '$section'"
    return 0
}

function ini_format() {
    local file="$1"
    local indent="${2:-0}"
    local sort_keys="${3:-0}"
    
    # Validate parameters
    if [ -z "$file" ]; then
        ini_error "ini_format: Missing file parameter"
        return 1
    fi
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_error "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
    # Acquire lock for file writing
    local lock_fd
    lock_fd=$(ini_lock_file "$file") || return 1
    
    local temp_file
    temp_file=$(ini_create_temp_file) || {
        ini_unlock_file "$lock_fd"
        return 1
    }
    
    ini_debug "Formatting INI file: $file (indent=$indent, sort_keys=$sort_keys)"
    
    # Read all sections and keys into associative arrays
    declare -A section_keys
    local current_section=""
    local current_comment=""
    local keys_in_section=()
    local comments_before_section=()
    
    # First pass: collect all data
    local first_line=1
    while IFS= read -r line || [ -n "$line" ]; do
        # Remove BOM from first line if present
        if [ "$first_line" -eq 1 ]; then
            line=$(_ini_remove_bom "$line")
            first_line=0
        fi
        
        local trimmed_line
        trimmed_line=$(ini_trim "$line")
        
        # Handle comments
        if [[ "$trimmed_line" =~ ^[[:space:]]*[#\;](.*)$ ]]; then
            local comment="${BASH_REMATCH[1]}"
            comment=$(ini_trim "$comment")
            if [ -z "$current_section" ]; then
                comments_before_section+=("# $comment")
            else
                if [ -z "$current_comment" ]; then
                    current_comment="# $comment"
                else
                    current_comment="$current_comment\n# $comment"
                fi
            fi
            continue
        fi
        
        # Handle section headers
        if [[ "$trimmed_line" =~ ^\[([^]]+)\]$ ]]; then
            # Save previous section if exists
            if [ -n "$current_section" ] && [ ${#keys_in_section[@]} -gt 0 ]; then
                if [ "$sort_keys" -eq 1 ]; then
                    # Sort by key name (extract key from key=value)
                    local sorted_array=()
                    for entry in "${keys_in_section[@]}"; do
                        # Extract key part for sorting
                        local key_part="${entry%%=*}"
                        # Remove comment prefix if present
                        key_part="${key_part##*# }"
                        key_part="${key_part%%=*}"
                        sorted_array+=("${key_part}|${entry}")
                    done
                    local sorted_output
                    sorted_output=$(printf '%s\n' "${sorted_array[@]}" | sort -t'|' -k1 | cut -d'|' -f2-)
                    IFS=$'\n' read -d '' -ra sorted_entries <<< "$sorted_output" || true
                    keys_in_section=("${sorted_entries[@]}")
                fi
                section_keys["$current_section"]="${keys_in_section[*]}"
            fi
            
            current_section="${BASH_REMATCH[1]}"
            keys_in_section=()
            current_comment=""
            continue
        fi
        
        # Handle key=value pairs
        if [[ "$trimmed_line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            key=$(ini_trim "$key")
            value=$(ini_trim "$value")
            
            local key_value="$key=$value"
            if [ -n "$current_comment" ]; then
                key_value="$current_comment\n$key_value"
                current_comment=""
            fi
            keys_in_section+=("$key_value")
            continue
        fi
    done < "$file"
    
    # Save last section
    if [ -n "$current_section" ] && [ ${#keys_in_section[@]} -gt 0 ]; then
        if [ "$sort_keys" -eq 1 ]; then
            # Sort by key name (extract key from key=value)
            local sorted_array=()
            for entry in "${keys_in_section[@]}"; do
                # Extract key part for sorting
                local key_part="${entry%%=*}"
                # Remove comment prefix if present
                key_part="${key_part##*# }"
                key_part="${key_part%%=*}"
                sorted_array+=("${key_part}|${entry}")
            done
            local sorted_output
            sorted_output=$(printf '%s\n' "${sorted_array[@]}" | sort -t'|' -k1 | cut -d'|' -f2-)
            IFS=$'\n' read -d '' -ra sorted_entries <<< "$sorted_output" || true
            keys_in_section=("${sorted_entries[@]}")
        fi
        section_keys["$current_section"]="${keys_in_section[*]}"
    fi
    
    # Second pass: write formatted output
    # Write comments before first section
    for comment in "${comments_before_section[@]}"; do
        echo -e "$comment" >> "$temp_file"
    done
    
    # Get all sections
    local all_sections
    all_sections=$(ini_list_sections "$file")
    
    local first_section=1
    for section in $all_sections; do
        # Add blank line before section (except first)
        if [ $first_section -eq 0 ]; then
            echo "" >> "$temp_file"
        fi
        first_section=0
        
        # Write section header
        local indent_str=""
        if [ "$indent" -gt 0 ]; then
            indent_str=$(printf "%${indent}s" "")
        fi
        echo "${indent_str}[$section]" >> "$temp_file"
        
        # Write keys for this section
        if [ -n "${section_keys[$section]}" ]; then
            IFS=' ' read -ra keys_array <<< "${section_keys[$section]}"
            for key_entry in "${keys_array[@]}"; do
                # Handle multi-line entries (with comments)
                if [[ "$key_entry" =~ \\n ]]; then
                    echo -e "$key_entry" >> "$temp_file"
                else
                    echo "$key_entry" >> "$temp_file"
                fi
            done
        fi
    done
    
    # Create backup before atomic operation
    local backup_file=""
    if [ -f "$file" ]; then
        backup_file="${file}.bak.$$"
        if ! cp "$file" "$backup_file" 2>/dev/null; then
            ini_error "Failed to create backup"
            rm -f "$temp_file"
            ini_unlock_file "$lock_fd"
            return 1
        fi
    fi
    
    # Use atomic operation to replace the original file
    if ! mv "$temp_file" "$file" 2>/dev/null; then
        ini_error "Failed to atomically replace file"
        rm -f "$temp_file"
        [ -f "$backup_file" ] && rm -f "$backup_file"
        ini_unlock_file "$lock_fd"
        return 1
    fi
    
    # Remove from temp files tracking since we successfully moved it
    local new_array=()
    for item in "${_ini_temp_files[@]}"; do
        [ "$item" != "$temp_file" ] && new_array+=("$item")
    done
    _ini_temp_files=("${new_array[@]}")
    
    # Clean up backup after successful operation
    [ -f "$backup_file" ] && rm -f "$backup_file"
    
    # Release lock
    ini_unlock_file "$lock_fd"
    
    ini_debug "Successfully formatted file: $file"
    return 0
}

function ini_batch_write() {
    local file="$1"
    local section="$2"
    shift 2
    local key_value_pairs=("$@")
    
    # Validate parameters
    if [ -z "$file" ] || [ -z "$section" ] || [ ${#key_value_pairs[@]} -eq 0 ]; then
        ini_error "ini_batch_write: Missing required parameters"
        return 1
    fi
    
    # Validate section name only if strict mode is enabled
    if [ "${INI_STRICT}" -eq 1 ]; then
        ini_validate_section_name "$section" || return 1
    fi
    
    # Check and create file if needed
    ini_check_file "$file" || return 1
    
    # Create section if it doesn't exist
    ini_add_section "$file" "$section" || return 1
    
    ini_debug "Batch writing ${#key_value_pairs[@]} key-value pairs to section '$section' in file: $file"
    
    # Process each key=value pair
    local errors=0
    for pair in "${key_value_pairs[@]}"; do
        if [[ ! "$pair" =~ ^([^=]+)=(.*)$ ]]; then
            ini_error "Invalid key=value format: $pair"
            errors=$((errors + 1))
            continue
        fi
        
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        key=$(ini_trim "$key")
        value=$(ini_trim "$value")
        
        # Validate key name if strict mode
        if [ "${INI_STRICT}" -eq 1 ]; then
            if ! ini_validate_key_name "$key" >/dev/null 2>&1; then
                ini_error "Invalid key name: $key"
                errors=$((errors + 1))
                continue
            fi
        fi
        
        # Write the key-value pair
        if ! ini_write "$file" "$section" "$key" "$value"; then
            errors=$((errors + 1))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        ini_debug "Successfully batch wrote ${#key_value_pairs[@]} key-value pairs"
        return 0
    else
        ini_error "Batch write completed with $errors error(s)"
        return 1
    fi
}

function ini_merge() {
    local source_file="$1"
    local target_file="$2"
    local strategy="${3:-overwrite}"
    local merge_sections=("${@:4}")
    
    # Validate parameters
    if [ -z "$source_file" ] || [ -z "$target_file" ]; then
        ini_error "ini_merge: Missing required parameters"
        return 1
    fi
    
    # Validate strategy
    if [[ ! "$strategy" =~ ^(overwrite|skip|merge)$ ]]; then
        ini_error "ini_merge: Invalid strategy. Must be 'overwrite', 'skip', or 'merge'"
        return 1
    fi
    
    # Validate paths
    ini_validate_path "$source_file" || return 1
    ini_validate_path "$target_file" || return 1
    
    # Resolve symlinks
    local resolved_source
    resolved_source=$(ini_resolve_symlink "$source_file") || return 1
    
    # Check if source file exists
    if [ ! -f "$resolved_source" ]; then
        ini_error "Source file not found: $resolved_source"
        return 1
    fi
    
    # Check source file size
    ini_check_file_size "$resolved_source" || return 1
    
    # Check if source file is readable
    if [ ! -r "$resolved_source" ]; then
        ini_error "Source file is not readable: $resolved_source"
        return 1
    fi
    
    local source_file="$resolved_source"
    
    # Check and create target file if needed
    ini_check_file "$target_file" || return 1
    
    ini_debug "Merging '$source_file' into '$target_file' with strategy: $strategy"
    
    # Get sections from source file
    local sections
    sections=$(ini_list_sections "$source_file")
    
    # Filter sections if specific ones are provided
    if [ ${#merge_sections[@]} -gt 0 ]; then
        local filtered_sections=""
        for section in $sections; do
            for merge_section in "${merge_sections[@]}"; do
                if [ "$section" = "$merge_section" ]; then
                    filtered_sections="$filtered_sections $section"
                    break
                fi
            done
        done
        sections="$filtered_sections"
    fi
    
    # Loop through sections
    for section in $sections; do
        ini_debug "Merging section: $section"
        
        # Add the section to the target file if it doesn't exist
        ini_add_section "$target_file" "$section"
        
        # Get keys in this section from source
        local source_keys
        source_keys=$(ini_list_keys "$source_file" "$section")
        
        # Get keys in this section from target
        local target_keys
        target_keys=$(ini_list_keys "$target_file" "$section")
        
        # Loop through source keys
        for key in $source_keys; do
            local source_value
            source_value=$(ini_read "$source_file" "$section" "$key")
            
            # Check if key exists in target
            local key_exists=0
            for target_key in $target_keys; do
                if [ "$target_key" = "$key" ]; then
                    key_exists=1
                    break
                fi
            done
            
            # Apply merge strategy
            if [ $key_exists -eq 1 ]; then
                case "$strategy" in
                    overwrite)
                        ini_write "$target_file" "$section" "$key" "$source_value"
                        ;;
                    skip)
                        ini_debug "Skipping existing key: $key"
                        ;;
                    merge)
                        # For merge strategy, append source value to target value
                        local target_value
                        target_value=$(ini_read "$target_file" "$section" "$key")
                        local merged_value="${target_value},${source_value}"
                        ini_write "$target_file" "$section" "$key" "$merged_value"
                        ;;
                esac
            else
                # Key doesn't exist in target, always add it
                ini_write "$target_file" "$section" "$key" "$source_value"
            fi
        done
    done
    
    ini_debug "Merge completed successfully"
    return 0
}

function ini_to_json() {
    local file="$1"
    local pretty="${2:-0}"
    
    # Validate parameters
    if [ -z "$file" ]; then
        ini_error "ini_to_json: Missing file parameter"
        return 1
    fi
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_error "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
    ini_debug "Converting INI file to JSON: $file"
    
    # Helper function to escape JSON special characters
    _ini_json_escape() {
        local str="$1"
        str="${str//\\/\\\\}"
        str="${str//\"/\\\"}"
        str="${str//\//\\/}"
        str="${str//$'\b'/\\b}"
        str="${str//$'\f'/\\f}"
        str="${str//$'\n'/\\n}"
        str="${str//$'\r'/\\r}"
        str="${str//$'\t'/\\t}"
        echo "$str"
    }
    
    # Start JSON object
    if [ "$pretty" -eq 1 ]; then
        echo "{"
    else
        echo -n "{"
    fi
    
    local sections
    sections=$(ini_list_sections "$file")
    local first_section=1
    
    for section in $sections; do
        local escaped_section
        escaped_section=$(_ini_json_escape "$section")
        
        if [ "$pretty" -eq 1 ]; then
            if [ $first_section -eq 0 ]; then
                echo ","
            fi
            echo "  \"$escaped_section\": {"
        else
            if [ $first_section -eq 0 ]; then
                echo -n ","
            fi
            echo -n "\"$escaped_section\":{"
        fi
        
        first_section=0
        
        local keys
        keys=$(ini_list_keys "$file" "$section")
        local first_key=1
        
        for key in $keys; do
            local value
            value=$(ini_read "$file" "$section" "$key")
            local escaped_key
            escaped_key=$(_ini_json_escape "$key")
            local escaped_value
            escaped_value=$(_ini_json_escape "$value")
            
            if [ "$pretty" -eq 1 ]; then
                if [ $first_key -eq 0 ]; then
                    echo ","
                fi
                echo "    \"$escaped_key\": \"$escaped_value\""
            else
                if [ $first_key -eq 0 ]; then
                    echo -n ","
                fi
                echo -n "\"$escaped_key\":\"$escaped_value\""
            fi
            
            first_key=0
        done
        
        if [ "$pretty" -eq 1 ]; then
            echo -n "  }"
        else
            echo -n "}"
        fi
    done
    
    if [ "$pretty" -eq 1 ]; then
        echo ""
        echo "}"
    else
        echo "}"
    fi
    
    return 0
}

function ini_to_yaml() {
    local file="$1"
    local indent="${2:-2}"
    
    # Validate parameters
    if [ -z "$file" ]; then
        ini_error "ini_to_yaml: Missing file parameter"
        return 1
    fi
    
    # Validate path
    ini_validate_path "$file" || return 1
    
    # Resolve symlinks
    local resolved_file
    resolved_file=$(ini_resolve_symlink "$file") || return 1
    
    # Check if file exists
    if [ ! -f "$resolved_file" ]; then
        ini_error "File not found: $resolved_file"
        return 1
    fi
    
    # Check file size
    ini_check_file_size "$resolved_file" || return 1
    
    # Check if file is readable
    if [ ! -r "$resolved_file" ]; then
        ini_error "File is not readable: $resolved_file"
        return 1
    fi
    
    local file="$resolved_file"
    
    ini_debug "Converting INI file to YAML: $file"
    
    # Helper function to escape YAML special characters
    _ini_yaml_escape() {
        local str="$1"
        # Escape quotes and special characters if needed
        if [[ "$str" =~ [:\"\'\[\]\{\}\|\&\*\#\?] ]] || [[ "$str" =~ ^[[:space:]] ]] || [[ "$str" =~ [[:space:]]$ ]]; then
            str="\"${str//\"/\\\"}\""
        fi
        echo "$str"
    }
    
    local sections
    sections=$(ini_list_sections "$file")
    local first_section=1
    
    for section in $sections; do
        local escaped_section
        escaped_section=$(_ini_yaml_escape "$section")
        
        if [ $first_section -eq 0 ]; then
            echo ""
        fi
        first_section=0
        
        echo "$escaped_section:"
        
        local keys
        keys=$(ini_list_keys "$file" "$section")
        
        for key in $keys; do
            local value
            value=$(ini_read "$file" "$section" "$key")
            local escaped_key
            escaped_key=$(_ini_yaml_escape "$key")
            local escaped_value
            escaped_value=$(_ini_yaml_escape "$value")
            
            local indent_str
            indent_str=$(printf "%${indent}s" "")
            echo "${indent_str}${escaped_key}: ${escaped_value}"
        done
    done
    
    return 0
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