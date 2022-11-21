/// <reference types="cypress" />

describe('Configurator', () => {

  before(() => {
    // cy.pfConfiguratorEnable()
  })

  beforeEach(() => {
    cy.intercept('GET', '/api/**/config/interfaces?*').as('getInterfaces')
    cy.intercept('PATCH', '/api/**/config/interface/*').as('patchInterface')
    cy.intercept('PUT', '/api/**/config/system/gateway').as('setGateway')

    cy.visit('/')
  })

  it('SPA', () => {

    // assert URL redirect
    cy.url().should('include', '/admin#/configurator')

    /**
      * Step #1
     **/

    // wizard circle is highlighted
    cy.get('.wizard-sidebar div.bg-warning').last().should('contain', '1')

    // wait for API
    cy.wait('@getInterfaces').its('response.statusCode').should('be.oneOf', [200])

    // next button is disabled
    cy.get('button[type="button"]:contains(Next)').should('have.attr', 'disabled', 'disabled')

    // interface table at least 1 row, not contains 'management'
    cy.get('.card-body table.b-table tbody tr')
          .should('have.length.to.be.at.least', 1)
      .should('not.contain.text', 'management')

    // detect network button exists, click it
    cy.get('button:contains(Detect)').should('exist').click()

    // wait for API
    cy.wait('@patchInterface').its('response.statusCode').should('be.oneOf', [200])

    // interface table contains 'management'
    cy.get('.card-body table.b-table tbody tr').should('contain.text', 'management')

    // detect network button not exist
    cy.get('button:contains(Detect)').should('not.exist')

    // wait for form, then fill it out
    cy.get('.base-form').then(() => {
      cy.formFillNamespace('.base-form', { hostname: 'bar', gateway: 'foo' }).then(() => {
      })
    })

    // next button enabled
    cy.get('button[type="button"]:contains(Next)').should('not.have.attr', 'disabled')

    // click next button
    cy.get('button[type="button"]:contains(Next)').click()

    // wait for API
    cy.wait('@setGateway').its('response.statusCode').should('be.oneOf', [200])

  })

})
