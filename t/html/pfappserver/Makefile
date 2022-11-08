BASE_URL :=
CONFIG_FILE := cypress/config/cypress.config.js
CONFIG := env={}
#DEBUG := cypress:*
DEBUG :=

.PHONY: all install test

all:
	@echo "Usage:"
	@echo "make install-debian|install-rhel: install libraries"
	@echo "make install: install cypress"
	@echo "make test: run tests interactively (w/ X11 \$$DISPLAY)"
	@echo "make test-e2e: run tests headless"
	@echo ""
	@echo "make [target] BASE_URL=https://localhost:1443"
	@echo "make [target] CONFIG_FILE=cypress/config/cypress.config.js"
	@echo "make [target] CONFIG=downloadsFolder=/tmp/downloads,screenshotsFolder=/tmp/screenshots,videosFolder=/tmp/videos"
	@echo "make [target] DEBUG=cypress:*"
	@echo ""
	@echo "DISPLAY=\$$(cat /etc/resolv.conf | grep nameserver | awk '{print \$$2; exit;}'):0.0 make [target]"

install-rhel:
	yum install -y xorg-x11-server-Xvfb gtk2-devel gtk3-devel libnotify-devel GConf2 nss libXScrnSaver alsa-lib

install-debian:
	apt-get install libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libxtst6 xauth xvfb

install:
	npm install cypress -g --allow-root --unsafe-perm=true

test:
	DEBUG=$(DEBUG) cypress open --config-file $(CONFIG_FILE) --config $(CONFIG)

test-e2e:
	DEBUG=$(DEBUG) DISPLAY= BROWSERSLIST_IGNORE_OLD_DATA=true CYPRESS_baseUrl=$(BASE_URL) cypress run --e2e --headless --config-file $(CONFIG_FILE) --config $(CONFIG)
