const webpackPreprocessor = require('@cypress/webpack-preprocessor')
const webpackOptions = {
  webpackOptions: require('../../webpack.config'),
  watchOptions: {}
}

require('dotenv').config()

// screenshot and video resolution
const width = 3840 // 4k
const height = 2160 // 4k

// see https://docs.cypress.io/guides/references/configuration#Global

module.exports = {
//  defaultCommandTimeout: 10000, // 10s
  e2e: {
    baseUrl: 'https://localhost:1443',
    blockHosts: [
      'analytics.packetfence.org' // DNT
    ],
    setupNodeEvents: (on, config) => {
      on('file:preprocessor', webpackPreprocessor(webpackOptions));
      on('before:browser:launch', (browser = {}, launchOptions) => {
        switch (browser.name) {
          case 'chrome':
          case 'chrome:canary':
          case 'chromium':
            launchOptions.args.push('--disable-gpu'); // headless
            launchOptions.args.push(`--window-size=${width},${height}`)
            launchOptions.args.push('--force-device-scale-factor=1')
            break;
          case 'electron':
            launchOptions.preferences.width = width
            launchOptions.preferences.height = height
            break;
          case 'firefox':
            launchOptions.args.push('-headless'); // headless
            launchOptions.args.push(`--width=${width}`)
            launchOptions.args.push(`--height=${height}`)
            break;
        }
        return launchOptions;
      });
      on('task', {
        log(message) {
          console.log(`\t => ${message}`)
          return null
        }
      });
      on('task', {
        error(message) {
          console.error(`\t => ${message}`)
          return null
        }
      });
      return config;
    },
    env: {
      PARALLEL: +process.env.PARALLEL || 1,
      SLICE: +process.env.SLICE || 0,
    },
    specPattern: [
      'cypress/specs/e2e/*.cy.{js,jsx,ts,tsx}',
    ],
    testIsolation: true,
  },
  downloadsFolder: 'cypress/results/downloads',
  screenshotsFolder: 'cypress/results/screenshots',
  video: false,
  videosFolder: 'cypress/results/videos',
  viewportWidth: width,
  viewportHeight: height,

  // The number of tests for which snapshots and command data are kept in memory (default: 50).
  // Reduce this number if you are experiencing high memory consumption in your browser during a test run.
  numTestsKeptInMemory: 1,

  // Enables support for improved memory management within Chromium-based browsers.
  experimentalMemoryManagement: true,
};
