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
        if (browser.name == 'chrome') {
          launchOptions.args.push('--disable-gpu'); // headless
        }
        return launchOptions;
      });
      on('task', {
        log(message) {
          console.log(message)
          return null
        }
      })
      return config;
    },
    specPattern: [
      'cypress/specs/e2e/*.cy.{js,jsx,ts,tsx}',
    ],
    experimentalSessionAndOrigin: true,
    testIsolation: 'on',
  },
  downloadsFolder: 'cypress/results/downloads',
  screenshotsFolder: 'cypress/results/screenshots',
  video: false,
  videosFolder: 'cypress/results/videos',
  videoUploadOnPasses: false,
  viewportWidth: 1280,
  viewportHeight: 1024,

  // The number of tests for which snapshots and command data are kept in memory (default: 50).
  // Reduce this number if you are experiencing high memory consumption in your browser during a test run.
  numTestsKeptInMemory: 50,
};
