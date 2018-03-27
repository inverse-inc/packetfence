STATIC_FILES = ../admin/v-index.tt
DYNAMIC_FILES = dist/css/app.* dist/js/app.* dist/js/vendor.*
MANIFEST_FILES = dist/js/manifest.*

.PHONY: all dev dist

all:
	@echo "Use 'make dev' to generate the static JS/CSS files and 'make dist' to commit the distribution version."

dev:
	npm install
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
