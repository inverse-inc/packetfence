/// <reference types="cypress" />

context('Commands', () => {

  it('assert pfSystemLogin', () => {
    cy.pfSystemLogin().then(() => {
      // Cookie auth: a live session means token_info returns 200.
      cy.request('/api/v1/token_info').its('status').should('eq', 200)
    })
  })

  it('assert pfLogout', () => {
    cy.pfSystemLogin().then(() => {
      cy.pfLogout().then(() => {
        // After logout the session cookie is cleared/invalidated -> 401.
        cy.request({ url: '/api/v1/token_info', failOnStatusCode: false })
          .its('status').should('eq', 401)
      })
    })
  })

})
