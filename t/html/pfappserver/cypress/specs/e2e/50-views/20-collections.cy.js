/// <reference types="cypress" />

const { global, collections } = require('config');
const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('config/collections/config');

describe('Collections', () => {
  Object.values(collections).forEach(collection => {
    context(`Collection - ${collection.description}`, () => {
      beforeEach('Login as system', () => {
        cy.pfSystemLogin()
      })
      collection.tests.forEach(test => {
        const { description, scope, url, expect, form, interceptors = [], selectors } = test
        const { fixture = 'empty.json' } = form || {}
        const {
          buttonNewSelector = 'button[type="button"]:contains(New)',
          buttonCreateSelector = 'button[type="submit"]:contains(Create)',
          tabSelector = 'div.tabs a[role="tab"]',
        } = selectors || {}

        it(description, () => {

          // load page
          cy.visit(`${global.url}${url}`)

          switch (scope) {
            case SCOPE_INSERT:

              // click "New" button
              cy.get(buttonNewSelector).first().as('buttonNew')
              cy.get('@buttonNew')
                .should('not.have.class', 'disabled')
                .and('not.have.disabled', 'disabled')
                .click({ log: true })

              // expect url changed
              cy.url().should('include', `${url}/new`)

              // fill form with fixture
              cy.fixture(fixture).then(data => {

                // setup API interceptors
                interceptors.forEach((interceptor, i) => {
                  const { method, url, expect, timeout = 3E3 } = interceptor
                  cy.intercept({ method, url }, (req) => {
                    if (expect) {
                      req.destroy() // block
                      cy.window().then(() => {
                        expect(req, data) // expect
                      })
                    }
                    else {
                     req.continue() // passthrough
                    }
                  }).as(`interceptor${i}`)
                })

                if (Cypress.$(tabSelector).length) {
                  // iterate tabs (optional)
                  cy.get(tabSelector).each(async (tab, t, tabs) => {
                    if (tabs.length > 1) {
                      // click tab
                      await cy.get(tab, { timeout: 10E3 })
                        .click({ log: true })
                        .invoke('attr', 'aria-selected')
                        .should('eq', 'true')
                    }
                    // fill form
                    await cy.formFillNamespace(data)
                  })
                }
                else {
                  // fill form
                  cy.formFillNamespace(data)
                }

                // click "Create" button
                cy.window().then(() => {
                  cy.get(buttonCreateSelector).first().as('buttonCreate')
                  cy.get('@buttonCreate')
                    .should('not.have.class', 'disabled')
                    .and('not.have.disabled', 'disabled')
                    .click({ log: true })

                })
              })
              break

            case SCOPE_UPDATE:
            case SCOPE_DELETE:
            default:
              cy.task('error', `Unhandled scope '${scope || 'unknown'}'`)
          }

        })
      })
    })
  })
})