const collections = require('config/collections');

describe('Collections', () => {

  before('Login as system', () => {
    cy.pfConfiguratorDisable()
    cy.pfSystemLogin()
  })

  Object.values(collections).forEach(collection => {

    context(`${collection.name} List`, () => {

      beforeEach('Load URI', () => {
        cy.visit(`/admin#${collection.url}`)
      })

      it('assert add new button exists', () => {
        cy.get('form button[type="submit"]').first().as('btnSubmit')
        cy.get('@btnSubmit')
          .should('have.class', 'disabled')
          .and('have.disabled', 'disabled')
      })

    })

  })
});