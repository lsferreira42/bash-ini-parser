#!/bin/bash

# Build script to generate HTML file from template_poc.html
# This script uses Node.js to read repository files and embed them into the template

# Exit on error
set -e

# Default output file
OUTPUT_FILE="index_poc.html"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "Building $OUTPUT_FILE from template_poc.html..."

# Check if template_poc.html exists
if [ ! -f "template_poc.html" ]; then
    echo "Error: template_poc.html not found!"
    exit 1
fi

# Check if Node.js is available
if ! command -v node >/dev/null 2>&1; then
    echo "Error: Node.js is required for this script to work properly."
    echo "Please install Node.js and try again."
    exit 1
fi

# Create default files if needed
if [ ! -d "examples" ]; then
    echo "Creating examples directory..."
    mkdir -p examples
fi

if [ ! -f "examples/demo.sh" ]; then
    echo "Creating default demo script..."
    cat > examples/demo.sh << 'EOF'
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
EOF
fi

# Create a new approach using Node.js to build the HTML file
echo "Creating a more robust build script..."
cat > build_web_temp.js << EOF
const fs = require('fs');
const path = require('path');

// File paths configuration
const files = {
  template: 'template_poc.html',
  output: '${OUTPUT_FILE}',
  lib: 'lib_ini.sh',
  config: {
    content: '[app]\\nname=My Application\\nversion=1.0.0\\nsupported_formats=jpg,png,gif'
  },
  examples: {
    dir: 'examples'
  }
};

// Read the template file
console.log('Reading template file...');
let templateContent = fs.readFileSync(files.template, 'utf8');

// Helper function to safely read a file
function readFileOrDefault(filePath, defaultContent = '') {
  try {
    if (fs.existsSync(filePath)) {
      return fs.readFileSync(filePath, 'utf8');
    }
    return defaultContent;
  } catch (err) {
    console.log(\`Warning: Could not read \${filePath}: \${err.message}\`);
    return defaultContent;
  }
}

// This is the proper way to safely insert file content into JavaScript string literals
// Using JSON.stringify ensures all special characters are properly escaped
function safeReplaceInHTML(html, placeholder, content) {
  // The JSON.stringify handles escaping of all special characters
  const safeContent = JSON.stringify(content).slice(1, -1);
  return html.replace(placeholder, safeContent);
}

// Process lib_ini.sh
console.log('Processing lib_ini.sh...');
const libContent = readFileOrDefault(files.lib);
templateContent = safeReplaceInHTML(templateContent, '<!-- LIB_INI_SH_CONTENT -->', libContent);

// Process all example files
console.log('Processing all example files...');
const examplesDir = files.examples.dir;

// Read all files from the examples directory
const exampleFiles = fs.readdirSync(examplesDir);

for (const file of exampleFiles) {
  const filePath = path.join(examplesDir, file);
  
  // Skip directories, only process files
  if (fs.statSync(filePath).isDirectory()) {
    continue;
  }
  
  console.log(\`Reading \${filePath}...\`);
  const content = readFileOrDefault(filePath);
  
  // Replace placeholder in examples directory
  const examplesPlaceholder = \`<!-- EXAMPLES_\${file.toUpperCase().replace(/\\./g, '_')}_CONTENT -->\`;
  templateContent = safeReplaceInHTML(templateContent, examplesPlaceholder, content);
  
  // Also replace in root directory for INI files
  if (file.endsWith('.ini')) {
    const rootPlaceholder = \`<!-- \${file.toUpperCase().replace(/\\./g, '_')}_CONTENT -->\`;
    templateContent = safeReplaceInHTML(templateContent, rootPlaceholder, content);
  }
  
  // Handle demo.sh separately
  if (file === 'demo.sh') {
    templateContent = safeReplaceInHTML(templateContent, '<!-- RUN_DEMO_SH_CONTENT -->', content);
  }
}

// Add config.ini content
console.log('Adding config.ini content...');
templateContent = safeReplaceInHTML(templateContent, '<!-- CONFIG_INI_CONTENT -->', files.config.content);

// Write the final file
console.log('Writing output file...');
fs.writeFileSync(files.output, templateContent);

console.log('Build completed successfully!');
EOF

# Run the Node.js build script
echo "Running build script..."
node build_web_temp.js

# Clean up temporary file
rm build_web_temp.js

echo "Build complete! $OUTPUT_FILE has been generated with proper escaping."
echo "All repository files have been embedded and lib_ini.sh is pre-loaded." 