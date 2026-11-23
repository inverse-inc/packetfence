FILES = dist/index.html dist/css/* dist/js/* dist/js/*

.PHONY: all vendor dev dist check-plugins-catalog

all:
	@echo "Use 'make vendor' to update external libraries, 'make dev' to generate the static JS/CSS files and 'make dist' to commit the distribution version."

vendor:
	npm install -g npm
	npm ci

dev:
	npm run build-debug

dist:
	npm run build
	git add -f $(FILES)
	@if ! git diff --cached --quiet --exit-code; then \
		git add --update dist; \
		git commit -m "(web admin) Update generated files"; \
	else \
		echo "Nothing to commit; skipping git-commit"; \
	fi

light-dist:
	npm run build

# the copies of the UI plugins catalog are current (run by CI, needs the whole
# repository: go/uiplugins and docs/ui-plugins)
check-plugins-catalog:
	node build/ui-plugins-catalog.js --check

clean:
	rm -rf ./node_modules
