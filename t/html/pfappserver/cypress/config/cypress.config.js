const webpackPreprocessor = require('@cypress/webpack-preprocessor')
const webpackOptions = {
  webpackOptions: require('../../webpack.config'),
  watchOptions: {}
}

// see https://docs.cypress.io/guides/references/configuration#Global

module.exports = {
  defaultCommandTimeout: 10000, // 10s
  e2e: {
    baseUrl: 'https://localhost:1443',
    setupNodeEvents: (on, config) => {
//console.info({config})
      on('file:preprocessor', webpackPreprocessor(webpackOptions))
      on('before:browser:launch', (browser = {}, launchOptions) => {
        if (browser.name == 'chrome') {
          launchOptions.args.push('--disable-gpu') // headless
        }
        return launchOptions
      })
    },
    specPattern: [
      'cypress/specs/e2e/*.cy.{js,jsx,ts,tsx}',
    ],
  },
  downloadsFolder: 'cypress/results/downloads',
  screenshotsFolder: 'cypress/results/screenshots',
  videosFolder: 'cypress/results/videos',
  videoUploadOnPasses: false,
  viewportWidth: 1280,
  viewportHeight: 1024,
};
