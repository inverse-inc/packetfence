BASE_URL :=
CONFIG_FILE := cypress/config/cypress.config.js
#DEBUG := cypress:*
DEBUG :=
X11DISPLAY :=

.PHONY: all install test

all:
	@echo "Usage:"
	@echo "make install-debian|install-rhel: update libraries, install cypress"
	@echo "make test: run tests interactively with X11 (see X11DISPLAY=)"
	@echo "make test-e2e: run tests headless"
	@echo ""
	@echo "make [target] BASE_URL=https://localhost:1443"
	@echo "make [target] CONFIG_FILE=cypress/config/cypress.config.js"
	@echo "make [target] DEBUG=cypress:*"
	@echo "make [target] X11DISPLAY=\$$(cat /etc/resolv.conf | grep nameserver | awk '{print \$$2; exit;}'):0.0"

install-rhel:
	yum install -y xorg-x11-server-Xvfb gtk2-devel gtk3-devel libnotify-devel GConf2 nss libXScrnSaver alsa-lib
	npm install cypress -g --allow-root --unsafe-perm=true

install-debian:
	apt-get install libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libxtst6 xauth xvfb
	npm install cypress -g --allow-root --unsafe-perm=true

test:
	DEBUG=$(DEBUG) cypress open --config-file=$(CONFIG_FILE)

test-e2e:
	DEBUG=$(DEBUG) DISPLAY=$(X11DISPLAY) BROWSERSLIST_IGNORE_OLD_DATA=true CYPRESS_baseUrl=$(BASE_URL) cypress run --e2e --headless --config-file=$(CONFIG_FILE)

