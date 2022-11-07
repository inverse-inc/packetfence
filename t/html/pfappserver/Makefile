FILES = dist/index.html dist/css/* dist/js/* dist/js/*

.PHONY: all vendor dev dist

all:
	@echo "Use 'make vendor' to update external libraries, 'make dev' to generate the static JS/CSS files and 'make dist' to commit the distribution version."

install:
	npm install cypress -g --allow-root --unsafe-perm=true

test:
	# DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2; exit;}'):0.0
	cypress open --config-file=cypress/config/cypress.config.js

test-e2e-configuration:
	DISPLAY= BROWSERSLIST_IGNORE_OLD_DATA=true CYPRESS_baseUrl= cypress run --e2e --headless --config-file=cypress/config/cypress.config-configuration.js

test-e2e-configurator:
	DISPLAY= BROWSERSLIST_IGNORE_OLD_DATA=true CYPRESS_baseUrl= cypress run --e2e --headless --config-file=cypress/config/cypress.config-configurator.js

test-e2e:
	DISPLAY= BROWSERSLIST_IGNORE_OLD_DATA=true CYPRESS_baseUrl= cypress run --e2e --headless --config-file=cypress/config/cypress.config.js

test-e2e-debug:
	DEBUG=cypress:* DISPLAY= CYPRESS_baseUrl= cypress run --e2e --headless --config-file=cypress/config/cypress.config.js
