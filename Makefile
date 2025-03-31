# Makefile for bash-ini-parser

.PHONY: web clean lint test

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

# Lint shell scripts with shellcheck
lint:
	@echo "Running shellcheck..."
	@shellcheck lib_ini.sh
	@shellcheck build_web_demo.sh
	@shellcheck run_tests.sh
	@echo "Lint complete."

# Run all tests
test:
	@echo "Running tests..."
	@chmod +x run_tests.sh
	@./run_tests.sh
	@echo "Tests complete."

help:
	@echo "Available targets:"
	@echo "  web    - Build the interactive web demo (index.html)"
	@echo "  clean  - Remove generated files"
	@echo "  lint   - Check shell scripts with shellcheck"
	@echo "  test   - Run all tests"
	@echo "  help   - Show this help message" 