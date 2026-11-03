FILES = dist/index.html dist/css/* dist/js/* dist/js/*

.PHONY: all vendor dev dist

all:
	@echo "Use 'make vendor' to update external libraries, 'make dev' to generate the static JS/CSS files and 'make dist' to commit the distribution version."

vendor:
	npm install -g npm
	npm ci

dev:
	npm run build-debug

dist:
	@# never commit a build with the UI extensions (private code, see extensions/README.md)
	@if [ "$$(node build/ui-extensions.js --list)" != "[]" ]; then \
		echo "UI extensions found, refusing to commit dist/ (use 'make light-dist')" >&2; \
		exit 1; \
	fi
	npm run build
	@# PF_UI_EXTENSIONS can also come from the .env* files Vue CLI loads: .pf-ui-extensions/ is only written when the build compiled extensions
	@if [ -e .pf-ui-extensions ]; then \
		echo "the build compiled UI extensions, refusing to commit dist/ (use 'make light-dist')" >&2; \
		exit 1; \
	fi
	git add -f $(FILES)
	@if ! git diff --cached --quiet --exit-code; then \
		git add --update dist; \
		git commit -m "(web admin) Update generated files"; \
	else \
		echo "Nothing to commit; skipping git-commit"; \
	fi

light-dist:
	npm run build

clean:
	rm -rf ./node_modules
