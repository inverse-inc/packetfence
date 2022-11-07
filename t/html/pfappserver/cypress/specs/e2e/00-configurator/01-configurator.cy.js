/// <reference types="cypress" />

context('Configurator', () => {

  before(() => {
    cy.pfConfiguratorEnable()
  })

  beforeEach(() => {
    cy.visit('/admin#/configurator')
  })

  it('assert configurator is enabled', () => {
    cy.get('.section-sidebar h6').should('contain', 'Configuration Wizard')
  })

})