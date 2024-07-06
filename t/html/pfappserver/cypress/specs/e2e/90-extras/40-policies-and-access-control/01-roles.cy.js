/// <reference types="cypress" />

describe('Roles', () => {

  context('Roles List', () => {

    before('Login as system', () => {
      cy.pfConfiguratorDisable()
      cy.pfSystemLogin()
    })

    beforeEach('Load URI', () => {
      cy.visit('/admin#/configuration/roles')
    })

    it('assert add new button exists', () => {
      cy.get('form button[type="submit"]').first().as('btnSubmit')
      cy.get('@btnSubmit')
        .should('have.class', 'disabled')
        .and('have.disabled', 'disabled')
    })

  })

})