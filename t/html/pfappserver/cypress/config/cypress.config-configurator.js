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
