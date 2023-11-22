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
        const { description, fixture = 'emtpy.json', scope, url, interceptors = [], selectors,
          idFromFixture = ({ id }) => id,
        } = test
        const {
          buttonNewSelectors = ['button[type="button"]:contains(New)'],
          buttonCreateSelector = 'button[type="submit"]:contains(Create)',
          buttonDeleteSelector = 'button[type="button"]:contains(Delete)',
          buttonDeleteConfirmSelector = 'button[type="button"][data-confirm]:contains(Delete)',
          buttonSaveSelector = 'button[type="submit"]:contains(Save)',
          tabSelector = 'div.tabs a[role="tab"]',
        } = selectors || {};
        it(description, () => {
          cy.fixture(fixture).then(async (data) => {
            const resourceId = idFromFixture(data)
            const resourceUrl = (url.constructor == Function) ? url(resourceId) : url
            switch (scope) {


              /**
               * SCOPE_INSERT
               */
              case SCOPE_INSERT:
                cy.visit(`${global.url}${url}`)

                // click "New" button(s)
                buttonNewSelectors.forEach((buttonNewSelector, n) => {
                  cy.get(buttonNewSelector).first().as(`buttonNew${n}`)
                  cy.get(`@buttonNew${n}`)
                    .should('not.have.class', 'disabled')
                    .and('not.have.disabled', 'disabled')
                    .click({ log: true })
                })

                // expect url changed
                cy.url().should('include', `${url}/new`)

                // setup API interceptors
                interceptors.forEach((interceptor, i) => {
                  const { method, url, expectRequest, timeout = global.interceptorTimeoutMs, block } = interceptor
                  cy.intercept({ method, url }, (request) => {
                    if (block) {
                      request.destroy() // block
                    }
                    else {
                      request.continue() // passthrough
                    }
                    if (expectRequest) {
                      expectRequest(request, data) // expect
                    }
                  }).as(`interceptor${i}`)
                })

                // iterate tabs (optional)
                if (Cypress.$(tabSelector).length) {
                  cy.get(tabSelector).each(async (tab, t, tabs) => {
                    if (tabs.length > 1) {
                      // click tab
                      cy.get(tab, { timeout: 10E3 })
                        .click({ log: true })
                        .invoke('attr', 'aria-selected').should('eq', 'true')
                    }
                    // fill form
                    await cy.formFillNamespace(data)
                  })
                }
                else {
                  // fill form
                  await cy.formFillNamespace(data)
                }

                // click "Create" button
                cy.get(buttonCreateSelector).first().as('buttonCreate')
                cy.get('@buttonCreate')
                  .should('not.have.class', 'disabled')
                  .and('not.have.disabled', 'disabled')
                  .click({ log: true })

                // wait, expect response
                interceptors.forEach(async (interceptor, i) => {
                  const { url, expectResponse, timeout = global.interceptorTimeoutMs } = interceptor
                  await cy.wait(`@interceptor${i}`, { timeout }).then(response => {
                    if (expectResponse) {
                      expectResponse(response, data)
                    }
                  })
                })
                break;


              /**
               * SCOPE_UPDATE
               */
              case SCOPE_UPDATE:

                // setup API interceptors
                interceptors.forEach((interceptor, i) => {
                  const { method, url, timeout = global.interceptorTimeoutMs, block } = interceptor
                  cy.intercept({ method, url }, (req) => {
                    if (block) {
                      req.destroy() // block
                    }
                    else {
                      req.continue() // passthrough
                    }
                  }).as(`interceptor${i}`)
                })

                cy.visit(`${global.url}${resourceUrl}`)

                // click "Save" button
                cy.get(buttonSaveSelector).first().as('buttonSave')
                cy.get('@buttonSave')
                  .should('not.have.class', 'disabled')
                  .and('not.have.disabled', 'disabled')
                  .click({ log: true })

                // wait, expect response
                interceptors.forEach(async (interceptor, i) => {
                  const { url, expectResponse, timeout = global.interceptorTimeoutMs } = interceptor
                  await cy.wait(`@interceptor${i}`, { timeout }).then(({ request, response }) => {
                    if (expectResponse) {
                      expectResponse(response, data)
                    }
                  })
                })
                break;


              /**
               * SCOPE_DELETE
               */
               case SCOPE_DELETE:
                // setup API interceptors
                interceptors.forEach((interceptor, i) => {
                  const { method, url, timeout = global.interceptorTimeoutMs, block } = interceptor
                  cy.intercept({ method, url }, (req) => {
                    if (block) {
                      req.destroy() // block
                    }
                    else {
                      req.continue() // passthrough
                    }
                  }).as(`interceptor${i}`)
                })

                cy.visit(`${global.url}${resourceUrl}`)

                // click "Delete" button
                cy.get(buttonDeleteSelector).first().as('buttonDelete')
                cy.get('@buttonDelete')
                  .should('not.have.class', 'disabled')
                  .and('not.have.disabled', 'disabled')
                  .click({ log: true })

                // click "Delete" button again (confirm)
                cy.get(buttonDeleteConfirmSelector).first().as('buttonDeleteConfirm')
                cy.get('@buttonDeleteConfirm')
                  .click({ log: true })

                // wait, expect response
                interceptors.forEach(async (interceptor, i) => {
                  const { url, expectResponse, timeout = global.interceptorTimeoutMs } = interceptor
                  await cy.wait(`@interceptor${i}`, { timeout }).then(({ request, response }) => {
                    if (expectResponse) {
                      expectResponse(response, data)
                    }
                  })
                })
                break;

              default:
                cy.task('error', `Unhandled scope '${scope || 'unknown'}'`)
            }
          })
        })
      })
    })
  })
})