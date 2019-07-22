CC ?= clang
PYTHON ?= python3
ROC ?= roc

.PHONY: all build test bench lint demo clean

all: build

build:
	@echo "==> Building C runtime and CLI..."
	$(MAKE) -C src/c all

test: build
	@echo "==> Running system-wide verification test suite..."
	./scripts/verify_all.sh

bench: build
	@echo "==> Running Dray micro-benchmarks..."
	./bin/dray bench

lint:
	@echo "==> Verifying zero prohibited dashes..."
	./scripts/lint_dashes.sh

demo: build
	@echo "==> Launching Dray interactive logistics simulation..."
	./bin/dray demo

clean:
	@echo "==> Cleaning build artifacts..."
	$(MAKE) -C src/c clean
	rm -rf bin lib __pycache__ src/python/__pycache__ src/python/pydray/__pycache__ src/python/tests/__pycache__
