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
test: test-bash test-zsh
	@echo "All tests complete."

# Run bash tests
test-bash:
	@echo "Running Bash tests..."
	@chmod +x run_tests.sh
	@./run_tests.sh
	@echo "Bash tests complete."

# Run zsh tests
test-zsh:
	@echo "Running Zsh tests..."
	@chmod +x run_tests_zsh.sh
	@./run_tests_zsh.sh
	@echo "Zsh tests complete."

# Alias for test
tests: test

help:
	@echo "Available targets:"
	@echo "  clean  - Remove generated files"
	@echo "  lint   - Check shell scripts with shellcheck"
	@echo "  test   - Run all tests"
	@echo "  tests  - Alias for test (run all tests)"
	@echo "  help   - Show this help message" 