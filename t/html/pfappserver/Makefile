#!make
include .local_env
export $(shell sed 's/=.*//' .local_env)

BASE_URL ?= https://localhost:1443
BROWSER ?= chrome
CONFIG_FILE ?= cypress/config/cypress.config.js
CONFIG ?= env={}
#DEBUG ?= cypress:*
DEBUG ?=
CI_PIPELINE_ID ?= $$(openssl rand -hex 16)
PROJECT_ID ?=
RECORD_KEY ?=

.PHONY: all install test

all:
	@echo "Usage:"
	@echo "make install-debian|install-rhel: install libraries"
	@echo "make install: install cypress"
	@echo "make test: run tests headless"
	@echo "make test-project: run tests headless in a project, requires PROJECT_ID and RECORD_KEY"
	@echo "make test-x11: run tests interactively (w/ X11 \$$DISPLAY)"
	@echo ""
	@echo "make [target] DEBUG=cypress:* (see https://docs.cypress.io/guides/references/troubleshooting#Log-sources)"
	@echo "make [target] BROWSER=firefox:nightly"
	@echo "make [target] BASE_URL=https://localhost:1443"
	@echo "make [target] CONFIG_FILE=cypress/config/cypress.config.js"
	@echo "make [target] CONFIG=downloadsFolder=/tmp/downloads,screenshotsFolder=/tmp/screenshots,videosFolder=/tmp/videos"
	@echo "make [target] PROJECT_ID=abcdef"
	@echo "make [target] RECORD_KEY=01234567-890a-bcde-f012-34567890abcd"
	@echo "make [target] TAG=production"
	@echo "make [target] TAGS=foo,bar"
	@echo ""
	@echo "DISPLAY=\$$(cat /etc/resolv.conf | grep nameserver | awk '{print \$$2; exit;}'):0.0 make [target]"

install-rhel:
	yum install -y xorg-x11-server-Xvfb gtk2-devel gtk3-devel libnotify-devel GConf2 nss libXScrnSaver alsa-lib
	yum install -y firefox

install-debian:
	apt-get update -y
	apt-get install -y libgtk2.0-0 libgtk-3-0 libgbm-dev libnotify-dev libgconf-2-4 libnss3 libxss1 libasound2 libxtst6 xauth xvfb
	apt-get install -y firefox-esr

install:
	npm install -g npm
	npm install cypress -g --allow-root --unsafe-perm=true
	npm install --legacy-peer-deps

test:
		DEBUG=$(DEBUG) \
		DISPLAY= \
		NO_COLOR=1 \
		BROWSERSLIST_IGNORE_OLD_DATA=true \
		CYPRESS_baseUrl=$(BASE_URL) \
		cypress run --browser $(BROWSER) --config-file $(CONFIG_FILE) --config $(CONFIG) --e2e --env tags=[$(TAGS)] ; \

test-project:
		DEBUG=$(DEBUG) \
		DISPLAY= \
		NO_COLOR=1 \
		BROWSERSLIST_IGNORE_OLD_DATA=true \
		CYPRESS_baseUrl=$(BASE_URL) \
		cypress run --browser $(BROWSER) --config-file $(CONFIG_FILE) --config projectId=$(PROJECT_ID),$(CONFIG) --e2e --ci-build-id $(CI_PIPELINE_ID) --parallel --record --key $(RECORD_KEY) --tag $(TAG) --env tags=[$(TAGS)] ; \

test-x11:
	DEBUG=$(DEBUG) \
	CYPRESS_baseUrl=$(BASE_URL) \
	cypress open --browser $(BROWSER) --config-file $(CONFIG_FILE) --config $(CONFIG)
