CSS_FILES = styles.css styles.css.map

all:
	@echo "Use 'make dev' to generate the stylesheet and 'make dist' to commit the distribution version."

dev:
	npm install --production
	grunt --stack dev

dist:
	grunt --stack dist
	git update-index --no-assume-unchanged $(CSS_FILES)
	git add -f $(CSS_FILES)
	@if ! git diff --cached --quiet --exit-code; then \
		git commit -m "(web common) Update generated files"; \
	else \
		echo "Nothing to commit; skipping git-commit"; \
	fi
	git update-index --assume-unchanged $(CSS_FILES) $(JS_FILES) $(JS_LIB_FILES)
