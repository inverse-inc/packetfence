/// <reference types="cypress" />

describe('Configurator', () => {

  before(() => {
    // cy.pfConfiguratorEnable()
  })

  beforeEach(() => {
    cy.intercept('GET', '/api/**/config/interfaces?*').as('getInterfaces')
    cy.intercept('PATCH', '/api/**/config/interface/*').as('patchInterface')

    cy.visit('/')
  })

  it('URL redirect', () => {
    cy.url().should('include', '/admin#/configurator')
  })

  it('Configurator is enabled', () => {
    cy.get('.section-sidebar h6').should('contain', 'Configuration Wizard')
  })

  describe('Step #1', () => {

    before(() => {
      cy.visit('/admin#/configurator')
    })

    it('Next button disabled', () => {
      cy.get('button[type="button"]:contains(Next)').should('have.attr', 'disabled', 'disabled')
    })

    it('Wizard circle highlighted', () => {
      cy.get('.wizard-sidebar div.bg-warning').last().should('contain', '1')
    })

    it('Interfaces', () => {

      cy.wait('@getInterfaces').its('response.statusCode').should('be.oneOf', [200])

      cy.get('.card-body table.b-table tbody tr')
        .should('have.length.to.be.at.least', 1)
        .should('not.contain.text', 'management')
        .should('contain.text', 'none')

      cy.get('button:contains(Detect)').should('exist').click()

      cy.wait('@patchInterface').its('response.statusCode').should('be.oneOf', [200])

      cy.get('.card-body table.b-table tbody tr')
      .should('have.length.to.be.at.least', 1)
      .should('contain.text', 'management')

      cy.get('button:contains(Detect)').should('not.exist')

    })


    it('Next button enabled', () => {
      cy.get('button[type="button"]:contains(Next)').should('not.have.attr', 'disabled')
    })

    it('Die', () => {
      cy.get('button[type="button"]:contains(Next)').should('have.attr', 'foo', 'bar')
    })


  })


  describe('Step #2', () => {
  })

  describe('Step #3', () => {
  })

  describe('Step #4', () => {
  })

})