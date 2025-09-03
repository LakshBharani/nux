.PHONY: help build clean release test install tap-update

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build nux in Release configuration
	xcodebuild -project nux.xcodeproj -scheme nux -configuration Release SYMROOT=build

clean: ## Clean build artifacts
	rm -rf build/
	rm -rf release/
	rm -rf DerivedData/

release: ## Build release version (specify VERSION=1.0.0)
	@if [ -z "$(VERSION)" ]; then echo "Please specify VERSION=1.0.0"; exit 1; fi
	./scripts/build-release.sh $(VERSION)

test: ## Run tests
	xcodebuild -project nux.xcodeproj -scheme nux -configuration Debug test

install: ## Install nux to Applications (requires sudo)
	@if [ -z "$(VERSION)" ]; then echo "Please specify VERSION=1.0.0"; exit 1; fi
	sudo cp -R release/nux.app /Applications/

tap-update: ## Update the tap with new version (specify VERSION=1.0.0)
	@if [ -z "$(VERSION)" ]; then echo "Please specify VERSION=1.0.0"; exit 1; fi
	@echo "Updating tap to version $(VERSION)..."
	@echo "1. Update Casks/nux.rb with version $(VERSION)"
	@echo "2. Update SHA256 hash"
	@echo "3. Commit and push to homebrew-tap repository"

deps: ## Install development dependencies
	brew install xcodegen

format: ## Format Swift code
	swiftformat nux/

lint: ## Lint Swift code
	swiftlint lint nux/

setup: ## Setup development environment
	git config core.hooksPath .githooks
	chmod +x scripts/*.make
