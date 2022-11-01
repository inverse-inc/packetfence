/// <reference types="cypress" />

context('Roles', () => {

  before('Login as system', () => {
    cy.pfSystemLogin()
  })

  beforeEach('Load URI', () => {
    cy.visit('/admin#/configuration/roles')
  })

  it('assert login button is disabled when form is empty', () => {
    cy.get('form button[type="submit"]').first().as('btnSubmit')
    cy.get('@btnSubmit')
      .should('have.class', 'disabled')
      .and('have.disabled', 'disabled')
  })
})