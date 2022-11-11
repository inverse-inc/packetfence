#!make
include .local_env
export $(shell sed 's/=.*//' .local_env)

BASE_URL ?= https://localhost:1443
CONFIG_FILE ?= cypress/config/cypress.config.js
CONFIG ?= env={}
#DEBUG ?= cypress:*
DEBUG ?=
BUILD_ID ?= $$(openssl rand -hex 16)
PROJECT_ID ?=
RECORD_KEY ?=

.PHONY: all install test

all:
	@echo "Usage:"
	@echo "make install-debian|install-rhel: install libraries"
	@echo "make install: install cypress"
	@echo "make test: run tests headless"
	@echo "make test-e2e: run tests headless, requires PROJECT_ID and RECORD_KEY"
	@echo "make test-x11: run tests interactively (w/ X11 \$$DISPLAY)"
	@echo ""
	@echo "make [target] DEBUG=cypress:*"
	@echo "make [target] BASE_URL=https://localhost:1443"
	@echo "make [target] CONFIG_FILE=cypress/config/cypress.config.js"
	@echo "make [target] CONFIG=downloadsFolder=/tmp/downloads,screenshotsFolder=/tmp/screenshots,videosFolder=/tmp/videos"
	@echo "make [target] PROJECT_ID=abcdef"
	@echo "make [target] RECORD_KEY=01234567-890a-bcde-f012-34567890abcd"
	@echo "make [target] TAG=production"
	@echo ""
	@echo "DISPLAY=\$$(cat /etc/resolv.conf | grep nameserver | awk '{print \$$2; exit;}'):0.0 make [target]"

install-rhel:
	yum install -y xorg-x11-server-Xvfb gtk2-devel gtk3-devel libnotify-devel GConf2 nss libXScrnSaver alsa-lib

install-debian:
	apt-get install libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libxtst6 xauth xvfb

install:
	npm install cypress -g --allow-root --unsafe-perm=true

test:
		DEBUG=$(DEBUG) \
		DISPLAY= \
		BROWSERSLIST_IGNORE_OLD_DATA=true \
		CYPRESS_baseUrl=$(BASE_URL) \
		cypress run --config-file $(CONFIG_FILE) --config $(CONFIG) --e2e --headless --tag $(TAG) ; \

test-e2e:
		DEBUG=$(DEBUG) \
		DISPLAY= \
		BROWSERSLIST_IGNORE_OLD_DATA=true \
		CYPRESS_baseUrl=$(BASE_URL) \
		cypress run --config-file $(CONFIG_FILE) --config projectId=$(PROJECT_ID),$(CONFIG) --e2e --ci-build-id $(BUILD_ID) --headless --parallel --record --key $(RECORD_KEY) --tag $(TAG) ; \

test-x11:
	DEBUG=$(DEBUG) \
	CYPRESS_baseUrl=$(BASE_URL) \
	cypress open --config-file $(CONFIG_FILE) --config $(CONFIG)
