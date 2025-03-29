# Makefile for bash-ini-parser

.PHONY: web clean

# Build the web demo
web:
	@echo "Building web demo..."
	@chmod +x build_web_demo.sh
	@./build_web_demo.sh

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@rm -f index_poc.html
	@echo "Clean complete."

help:
	@echo "Available targets:"
	@echo "  web    - Build the interactive web demo (index_poc.html)"
	@echo "  clean  - Remove generated files"
	@echo "  help   - Show this help message" 