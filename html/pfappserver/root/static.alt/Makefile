STATIC_FILES = ../admin/v-index.tt
DYNAMIC_FILES = dist/css/* dist/js/* dist/js/*

$(eval OUTPUT_RC="$(shell whoami;echo $$?)")
$(eval OUTPUT="$(shell echo $(OUTPUT_RC) | sed -e "s/^\(.*\)\(.\{2\}\)$$/\1/")")
export PATH := /usr/local/bin/:$(PATH)

.PHONY: all vendor dev dist

all:
	@echo "Use 'make vendor' to update external libraries, 'make dev' to generate the static JS/CSS files and 'make dist' to commit the distribution version."

vendor:
	sudo chown -R $(OUTPUT) ~/.npm
	npm config set cache /tmp
	npm install

dev:
	npm run build

dist:
	npm run build
	git add -f $(STATIC_FILES) $(DYNAMIC_FILES)
	@if ! git diff --cached --quiet --exit-code; then \
		git add --update dist; \
		git commit -m "(web admin alt) Update generated files"; \
	else \
		echo "Nothing to commit; skipping git-commit"; \
	fi


light-dist:
	npm run build
