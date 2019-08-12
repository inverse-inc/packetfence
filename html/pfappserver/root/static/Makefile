JS_FILES = js/pfappserver.* js/reports.* js/auditing.* js/configuration.*
JS_LIB_FILES = js/vendor/bootstrap.min.js* js/vendor/jquery.min.* js/vendor/jquery-ui.min.js* js/vendor/jquery-extra.min.js* js/vendor/raphael.min.js* js/vendor/ace/*.js js/vendor/fitty.min.js*
CSS_FILES = css/styles.css css/styles.css.map

$(eval OUTPUT_RC="$(shell whoami;echo $$?)")
$(eval OUTPUT="$(shell echo $(OUTPUT_RC) | sed -e "s/^\(.*\)\(.\{2\}\)$$/\1/")")
export PATH := /usr/local/bin/:$(PATH)
export npm_config_cache = /tmp

.PHONY: all vendor dev dist

all:
	@echo "Use 'make vendor' to update external libraries, 'make dev' to generate the static JS/CSS files and 'make dist' to commit the distribution version."

vendor:
	sudo chown -R $(OUTPUT) ~/.npm
	sudo mkdir -p ~/.config/configstore
	sudo chown -R $(OUTPUT) ~/.config
	npm install
	sudo npm install -g grunt-cli
	sudo npm install -g bower
	@if [ -d bower_components ]; then \
	  bower update --allow-root; \
	else \
	  bower install --allow-root; \
	fi

dev:
	grunt --stack vendor js css

dist:
	grunt --stack dist
	git add -f $(CSS_FILES) $(JS_FILES) $(JS_LIB_FILES)
	@if ! git diff --cached --quiet --exit-code; then \
		git commit -m "(web admin) Update generated files"; \
	else \
		echo "Nothing to commit; skipping git-commit"; \
	fi

light-dist:
	grunt --stack dist
