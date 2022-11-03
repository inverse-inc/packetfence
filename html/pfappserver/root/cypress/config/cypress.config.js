module.exports = {
  defaultCommandTimeout: 10000, // 10s
  e2e: {
    baseUrl: 'https://localhost:1443',
    setupNodeEvents(on, config) {
//      console.info(config)
      on('before:browser:launch', (browser = {}, launchOptions) => {
//        console.info({ browser, launchOptions })
        if (browser.name == 'chrome') {
          launchOptions.args.push('--disable-gpu') // headless
        }
        return launchOptions
      })
    },
    specPattern: [
      'cypress/e2e/*.cy.{js,jsx,ts,tsx}',
    ],
  },
  viewportWidth: 1280,
  viewportHeight: 1024,
};
