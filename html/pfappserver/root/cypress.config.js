module.exports = {
  e2e: {
    baseUrl: 'https://localhost:1443',
    setupNodeEvents(on, config) {
      // implement node event listeners here
    },
    defaultCommandTimeout: 10000, // 10s
    specPattern: [
      'cypress/e2e/**/*.cy.{js,jsx,ts,tsx}',
      'cypress/e2e/**/**/*.cy.{js,jsx,ts,tsx}',
    ]
  },
};
