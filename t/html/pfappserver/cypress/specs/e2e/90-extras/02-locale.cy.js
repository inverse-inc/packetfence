/// <reference types="cypress" />

context('Locale', () => {

  before(() => {
    cy.pfConfiguratorDisable()
    cy.pfSystemLogin()
  })

  beforeEach(() => {
    cy.visit('/admin')
  })

})