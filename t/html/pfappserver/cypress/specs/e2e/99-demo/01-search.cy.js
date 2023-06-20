/// <reference types="cypress" />

const searchString = 'PacketFence'

describe('GitHub Search', () => {

  beforeEach(() => {
    cy.visit('/')
  })

  it(`Assert search for "${searchString}" returns results.`, () => {

    cy.get('*[aria-label^="Search"]').first().as('input')
    cy.get('@input')
      .should('not.have.class', 'disabled')
      .and('not.have.disabled', 'disabled')
    cy.get('@input').type(searchString)

    cy.get('*[aria-label="in all of GitHub"]:not(.d-none)').first().as('button')
    cy.get('@button')
      .should('not.have.class', 'disabled')
      .and('not.have.disabled', 'disabled')
    cy.get('@button').click()

    cy.get('.repo-list').as('results')
    cy.get('@results')
      .should('contain.text', searchString)
  })

  it(`Assert search for "foobar" returns results.`, () => {

    cy.get('*[aria-label^="Search"]').first().as('input')
    cy.get('@input')
      .should('not.have.class', 'disabled')
      .and('not.have.disabled', 'disabled')
    cy.get('@input').type("foobar")

    cy.get('*[aria-label="in all of GitHub"]:not(.d-none)').first().as('button')
    cy.get('@button')
      .should('not.have.class', 'disabled')
      .and('not.have.disabled', 'disabled')
    cy.get('@button').click()

    cy.get('.repo-list').as('results')
    cy.get('@results')
      .should('contain.text', searchString)
  })

})
