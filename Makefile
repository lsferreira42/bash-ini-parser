# Makefile for bash-ini-parser

.PHONY: web clean

# Build the web demo
web:
	@echo "Building web demo..."
	@chmod +x build_web_demo.sh
	@./build_web_demo.sh --output index.html
	@echo "Generated index.html"

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -f index.html
	@echo "Clean complete."

help:
	@echo "Available targets:"
	@echo "  web    - Build the interactive web demo (index.html)"
	@echo "  clean  - Remove generated files"
	@echo "  help   - Show this help message" 