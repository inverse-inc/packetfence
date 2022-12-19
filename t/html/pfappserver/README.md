# End To End (E2E) Testing - Pfappserver

## Installation

 `cypress` is installed with `nodejs` (>= 14.20) using `npm` (>= 8).

```bash
node --version
v14.20.0

npm --version
8.19.2

cd /usr/local/pf/t/html/pfappserver
```


### Install dependancies

Install cypress dependancies using `yum` (rhel), `apt-get` (debian).

```bash
# RHEL
make install-rhel

# Debian
make install-debian
```

### Install Cypress

Install cypress `npm -g` for the local user in `~/.npm`.

Install local npm project `npm ci`.

```bash
make install
```

## ENV Variables

See [`Makefile`](Makefile) for usage.

* __DEBUG__: Cypress debug (example: DEBUG=cypress:*, default: none), (see https://docs.cypress.io/guides/references/troubleshooting#Log-sources).
* __BASE_URL__: Base URL used within tests (default: BASE_URL=https://localhost:1443).
* __CONFIG_FILE__: Cypress configuration file (default: cypress/config/cypress.config.js).
* __CONFIG__: Comma-separated list of configuration file overloads. (example CONFIG=downloadsFolder=/tmp/downloads,screenshotsFolder=/tmp/screenshots,videosFolder=/tmp/videos).
* __PROJECT_ID__: Cypress Cloud Project ID. Only used in `make test-e2e`.
* __RECORD_KEY__: Cypress Cloud Recording Key. Only used in `make test-e2e`.
* __TAG__: Optional Tag shown in Cypress Cloud test runs.

## Local Development Setup

Define ENV variables passed to Cypress. Edit [`t/html/pfappserver/.local_env`](.local_env).

```bash
#DEBUG=cypress:*
PROJECT_ID=f00b4r
RECORD_KEY=01234567-0123-0123-0123-0123456789ab
TAG=development
```

## Local tests

Run a local test using cypress.

```bash
make test

DEBUG= \
	DISPLAY= \
	NO_COLOR=1 \
	BROWSERSLIST_IGNORE_OLD_DATA=true \
	CYPRESS_baseUrl=https://localhost:1443 \
	cypress run --config-file cypress/config/cypress.config.js --config env={} --e2e --headless --env tags=[] ; \
```

The default configuration file ([`cypress/config/cypress.config.js`](cypress/config/cypress.config.js)) includes the specPattern that tests the local commands.

* __cypress/specs/e2e/00-commands.cy.js__

When writing tests inherit the default configuration and overload the `specPattern` and any other config.

Using ([`cypress/config/cypress.config-configurator.js`](cypress/config/cypress.config-configurator.js)) the ES6 spread operator is used to overload the default configuration:

```javascript
const config = require('./cypress.config.js');

module.exports = {
  ...config,

  e2e: {
    ...config.e2e,

    specPattern: [
      'cypress/specs/e2e/*-configurator/**/*.cy.{js,jsx,ts,tsx}',
    ],
    experimentalSessionAndOrigin: false,
    testIsolation: null,
  }
};
```

Run this test using `CONFIG_FILE`:

```bash
make test CONFIG_FILE=cypress/config/cypress.config-configurator.js

DEBUG= \
	DISPLAY= \
	NO_COLOR=1 \
	BROWSERSLIST_IGNORE_OLD_DATA=true \
	CYPRESS_baseUrl=https://localhost:1443 \
	cypress run --config-file cypress/config/cypress.config-configurator.js --config env={} --e2e --headless --env tags=[] ; \
```

Results are saved in `cypress/results/`:

```bash
tree cypress/results/

cypress/results/
├── screenshots
│   └── 01-configurator.cy.js
│       └── Configurator [null] -- SPA (failed).png
└── videos
```

## E2E Tests

Ensure you have setup a Cypress Cloud Account and setup the `PROJECT_ID` and `RECORD_KEY` in [`t/html/pfappserver/.local_env`](.local_env) (see above).

```bash
make test-e2e CONFIG_FILE=cypress/config/cypress.config-configurator.js

DEBUG= \
	DISPLAY= \
	NO_COLOR=1 \
	BROWSERSLIST_IGNORE_OLD_DATA=true \
	CYPRESS_baseUrl=https://localhost:1443 \
	cypress run --config-file cypress/config/cypress.config-configurator.js --config projectId=f00b4r,env={} --e2e --ci-build-id $(openssl rand -hex 16) --headless --parallel --record --key 01234567-0123-0123-0123-0123456789ab --tag development --env tags=[] ; \

...

Recorded Run: https://cloud.cypress.io/projects/f00b4r/runs/298
```

Results are not saved on disk but are uploaded and available at the URL provided at the tail of the test. These uploaded artifacts are counted towards the Cypress Cloud Account defined in the `PROJECT_ID`.
