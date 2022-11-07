/// <reference types="cypress" />

context('Commands', () => {

  it('assert pfSystemLogin', () => {
    cy.pfSystemLogin().then(() => {
      expect(localStorage.getItem('user-token')).to.not.be.null
    })
  })

  it('assert pfLogout', () => {
    cy.pfLogout().then(() => {
      expect(localStorage.getItem('user-token')).to.be.null
    })
  })

})