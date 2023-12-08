/// <reference types="cypress" />
const { global, collections } = require('config');
const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('config/collections/config');

describe('Collections', () => {
  Object.values(collections).forEach(collection => {
    context(`Collection - ${collection.description}`, () => {
      beforeEach('Login as system', () => {
        cy.session('system', () => {
          cy.pfSystemLogin()
        })
      })
      collection.tests.forEach(test => {
        const { description, fixture = 'emtpy.json', scope, url, interceptors = [], selectors, timeout,
          idFromFixture = ({ id }) => id,
          beforeFormFill,
        } = test
        const {
          containerSelector = 'div[data-router-view] > div > div.card',
          buttonNewSelectors = ['button[type="button"]:contains(New)'],
          buttonCreateSelector = 'button[type="submit"]:contains(Create)',
          buttonDeleteSelector = 'button[type="button"]:contains(Delete)',
          buttonDeleteConfirmSelector = 'button[type="button"][data-confirm]:contains(Delete)',
          buttonSaveSelector = 'button[type="submit"]:contains(Save)',
          tabSelector = 'div.tabs a[role="tab"]',
        } = selectors || {};
        const selectorOptions = { timeout }

        it(description, () => {
          cy.fixture(fixture).then((data) => {
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
                  cy.get(buttonNewSelector, selectorOptions).first().as(`buttonNew${n}`)
                  cy.get(`@buttonNew${n}`, selectorOptions)
                    .should('not.have.class', 'disabled')
                    .and('not.have.disabled', 'disabled')
                    .click({ log: true, force: true })
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

                cy.get(containerSelector, selectorOptions).then($body => { // DOM ready
                  // wait for progress
                  cy.get('div.progress[style*="display: none"]', selectorOptions).should('exist')

                  // iterate tabs (optional)
                  if ($body.find(tabSelector).length) {
                    cy.get(tabSelector, selectorOptions).each((tab, n) => {
                      // click tab
                      cy.get(tab, selectorOptions)
                        .click({ log: true })
                        .invoke('attr', 'aria-selected').should('eq', 'true')

                      cy.get(`div[role="tabpanel"]:nth-child(${n + 1})`, selectorOptions).as(`tab${n}`)
                      cy.get(`@tab${n}`, selectorOptions)
                        .invoke('attr', 'aria-hidden').should('eq', 'false')

                      // before form fill
                      if (beforeFormFill) {
                        beforeFormFill(`@tab${n}`, selectorOptions)
                      }

                      // fill form
                      cy.formFillNamespace(data, `@tab${n}`)
                    })

                    // click first tab
                    cy.get(tabSelector, selectorOptions).first()
                      .click({ log: true })
                      .invoke('attr', 'aria-selected').should('eq', 'true')
                  }
                  else {
                    // before form fill
                    if (beforeFormFill) {
                      beforeFormFill(`@tab${n}`, selectorOptions)
                    }

                    // fill form
                    cy.formFillNamespace(data, containerSelector)
                  }
                })

                // click "Create" button
                cy.get(buttonCreateSelector, selectorOptions).first().as('buttonCreate')
                cy.get('@buttonCreate', selectorOptions)
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

                cy.get(containerSelector, selectorOptions).then($body => { // DOM ready
                  // wait for progress
                  cy.get('div.progress[style*="display: none"]', selectorOptions).should('exist')

                  // click "Save" button
                  cy.get(buttonSaveSelector, selectorOptions).first().as('buttonSave')
                  cy.get('@buttonSave', selectorOptions)
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

                cy.get(containerSelector, selectorOptions).then($body => { // DOM ready
                  // wait for progress
                  cy.get('div.progress[style*="display: none"]', selectorOptions).should('exist')

                  // click "Delete" button
                  cy.get(buttonDeleteSelector, selectorOptions).first().as('buttonDelete')
                  cy.get('@buttonDelete', selectorOptions)
                    .should('not.have.class', 'disabled')
                    .and('not.have.disabled', 'disabled')
                    .click({ log: true })

                  // click "Delete" button again (confirm)
                  cy.get(buttonDeleteConfirmSelector, selectorOptions).first().as('buttonDeleteConfirm')
                  cy.get('@buttonDeleteConfirm', selectorOptions)
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