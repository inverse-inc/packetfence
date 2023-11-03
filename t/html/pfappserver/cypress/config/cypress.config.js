const webpackPreprocessor = require('@cypress/webpack-preprocessor')
const webpackOptions = {
  webpackOptions: require('../../webpack.config'),
  watchOptions: {}
}

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
            launchOptions.args.push('--disable-gpu'); // headless
            break;
          case 'firefox':
            launchOptions.args.push('-headless'); // headless
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
    specPattern: [
      'cypress/specs/e2e/*.cy.{js,jsx,ts,tsx}',
    ],
    testIsolation: true,
  },
  downloadsFolder: 'cypress/results/downloads',
  screenshotsFolder: 'cypress/results/screenshots',
  video: false,
  videosFolder: 'cypress/results/videos',
  viewportWidth: 1280,
  viewportHeight: 1024,

  // The number of tests for which snapshots and command data are kept in memory (default: 50).
  // Reduce this number if you are experiencing high memory consumption in your browser during a test run.
  numTestsKeptInMemory: 1,

  // Enables support for improved memory management within Chromium-based browsers.
  experimentalMemoryManagement: true,
};
