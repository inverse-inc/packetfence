STATIC_FILES = ../admin/v-index.tt
DYNAMIC_FILES = dist/css/app.* dist/js/app.* dist/js/vendor.* dist/js/[0-9]*
MANIFEST_FILES = dist/js/manifest.*

.PHONY: all vendor dev dist

all:
	@echo "Use 'make vendor' to update external libraries, 'make dev' to generate the static JS/CSS files and 'make dist' to commit the distribution version."

vendor:
	npm install

dev:
	npm run build-dev

dist:
	npm run build
	git add -f $(STATIC_FILES) $(DYNAMIC_FILES)
	@if ! git diff --cached --quiet --exit-code; then \
		git add --update dist; \
		git add -f $(MANIFEST_FILES); \
		git commit -m "(web admin alt) Update generated files"; \
	else \
		echo "Nothing to commit; skipping git-commit"; \
	fi
