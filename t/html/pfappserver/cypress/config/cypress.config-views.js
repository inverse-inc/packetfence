const config = require('./cypress.config.js');

module.exports = {
  ...config,

  e2e: {
    ...config.e2e,

    specPattern: [
      'cypress/specs/e2e/*-views/*.cy.{js,jsx,ts,tsx}',
      'cypress/specs/e2e/*-views/**/*.cy.{js,jsx,ts,tsx}',
    ],
  }
};
