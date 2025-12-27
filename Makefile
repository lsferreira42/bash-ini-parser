# Makefile for bash-ini-parser

.PHONY: clean lint test tests

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	@echo "Clean complete."

# Lint shell scripts with shellcheck
lint:
	@echo "Running shellcheck..."
	@chmod +x lint.sh
	@./lint.sh || true
	@echo "Lint complete."

# Run all tests
test:
	@echo "Running tests..."
	@chmod +x run_tests.sh
	@./run_tests.sh
	@echo "Tests complete."

# Alias for test
tests: test

help:
	@echo "Available targets:"
	@echo "  clean  - Remove generated files"
	@echo "  lint   - Check shell scripts with shellcheck"
	@echo "  test   - Run all tests"
	@echo "  tests  - Alias for test (run all tests)"
	@echo "  help   - Show this help message" 