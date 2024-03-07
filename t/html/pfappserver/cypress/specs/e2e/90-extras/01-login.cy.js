/// <reference types="cypress" />

context('Login', () => {

  before(() => {
    cy.pfConfiguratorDisable()
  })

  beforeEach(() => {
    cy.visit('/')
  })

  it('assert login button is disabled when form is empty', () => {
    cy.get('form button[type="submit"]').first().as('btnSubmit')
    cy.get('@btnSubmit')
      .should('have.class', 'disabled')
      .and('have.disabled', 'disabled')
  })

  it('assert login button is enabled when form is filled', () => {
    cy.get('form input#username').first().as('inputUsername')
    cy.get('form input#password').first().as('inputPassword')
    cy.get('form button[type="submit"]').first().as('btnSubmit')
    cy.get('@inputUsername').type('foo')
    cy.get('@inputPassword').type('bar')
    cy.get('@btnSubmit')
      .should('not.have.class', 'disabled')
      .and('not.have.disabled', 'disabled')
  })

  it('assert invalid login shows an alert', () => {
    cy.get('form input#username').first().as('inputUsername')
    cy.get('form input#password').first().as('inputPassword')
    cy.get('form button[type="submit"]').first().as('btnSubmit')
    cy.get('@inputUsername').type('foo')
    cy.get('@inputPassword').type('bar')
    cy.get('@btnSubmit').click()
    cy.get('form div[role="alert"]').first().should('contain', `Wasn't able to authenticate those credentials`)
  })

})