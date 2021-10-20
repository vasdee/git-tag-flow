# make sure we have bumpversion installed
ifeq (, $(shell which bumpversion))
$(error "No bumpversion in $(PATH), consider doing pip install bumpversion")
endif

version/patch: ## patch release
	bumpversion patch

version/minor: ## minor release
	bumpversion minor

version/major: ## major release
	bumpversion major


.DEFAULT_GOAL := help
.PHONY: help
help:
	@grep --no-filename -E '^[a-zA-Z_\/-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
