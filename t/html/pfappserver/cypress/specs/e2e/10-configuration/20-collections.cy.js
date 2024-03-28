/// <reference types="cypress" />
const { global, collections } = require('config');
const { flatten } = require('utils')
const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('config/collections/config');

const PARALLEL = Cypress.env('PARALLEL')
const SLICE = Cypress.env('SLICE')

describe('Collections', () => {
  Object.values(collections).forEach((collection, c) => {
    context(`Collection - ${collection.description}`, () => {
      beforeEach('Login as system', () => {
        cy.session('system', () => {
          cy.pfSystemLogin()
        })
      })
      let cache = {};
      collection.tests.forEach(test => {
        const { description, fixture = 'empty.json', flatten: flattenFixture, scope, url, interceptors = [], selectors, timeout,
          idFrom = ({ id }) => id,
          beforeFormFill,
          map = (v) => v,
        } = test
        const {
          containerSelector = 'div[data-router-view] > div > div.card',
          buttonNewSelectors = ['button[type="button"]:contains(New)'],
          buttonCreateSelector = 'button[type="submit"]:contains(Create)',
          buttonDeleteSelector = 'button[type="button"]:contains(Delete)',
          buttonDeleteConfirmSelector = 'button[type="button"][data-confirm]:contains(Delete)',
          buttonSaveSelector = 'button[type="submit"]:contains(Save)',
          tabSelector = 'div.tabs a[role="tab"]:is(:visible)',
        } = selectors || {};
        const selectorOptions = { timeout }

        const unit = () => {
          cy.fixture(fixture).then((data) => {
            const associative = (flattenFixture) ? flatten(data): data
            const form = Object.entries(associative).reduce((items, [k, v]) => {
              return { ...items, [k]: map(v, k) }
            }, {})
            const resourceId = idFrom(data, cache) // `id` may only be available post-create
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

                // expect new url
                cy.url().should('not.equal', url)

                // setup API interceptors
                interceptors.forEach((interceptor, i) => {
                  const { method, url, expectRequest, timeout = global.interceptorTimeoutMs, block } = interceptor
                  cy.intercept({ method, url }, (request) => {
                    if (expectRequest) {
                      let retVal = expectRequest(request, data, cache) // expect
                      request = retVal || request
                    }
                    if (block) {
                      request.destroy() // block
                    }
                    else {
                      request.continue() // passthrough
                    }
                  }).as(`interceptor${i}`)
                })

                // wait for progress
                cy.get('div.progress[style*="display: none"]', selectorOptions).should('exist')

                cy.get(containerSelector, selectorOptions).within($body => { // DOM ready

                  // iterate tabs (optional)
                  if ($body.find(tabSelector).length) {
                    cy.get(tabSelector, selectorOptions).should("have.length.gte", 0).then((tab, n) => {
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
                      cy.formFillNamespace(form, `@tab${n}`)
                    })

                    // click first tab
                    cy.get(tabSelector, selectorOptions).first()
                      .click({ log: true })
                      .invoke('attr', 'aria-selected').should('eq', 'true')
                  }
                  else {
                    // before form fill
                    if (beforeFormFill) {
                      beforeFormFill($body, selectorOptions)
                    }

                    // fill form
                    cy.formFillNamespace(form, $body)
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
                      let retVal = expectResponse(response, data, cache)
                      if (retVal) {
                        cache = { ...cache, ...retVal }
                      }
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
                  const { method, url, expectRequest, timeout = global.interceptorTimeoutMs, block } = interceptor
                  cy.intercept({ method, url }, (request) => {
                    if (expectRequest) {
                      let retVal = expectRequest(request, data, cache) // expect
                      request = retVal || request
                    }
                    if (block) {
                      request.destroy() // block
                    }
                    else {
                      request.continue() // passthrough
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
                        let retVal = expectResponse(response, data, cache)
                        if (retVal) {
                          cache = { ...cache, ...retVal }
                        }
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
                  cy.intercept({ method, url }, (request) => {
                    if (block) {
                      request.destroy() // block
                    }
                    else {
                      request.continue() // passthrough
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
                        let retVal = expectResponse(response, data, cache)
                        if (retVal) {
                          cache = { ...cache, ...retVal }
                        }
                      }
                    })
                  })
                })
                break;

              default:
                cy.task('error', `Unhandled scope '${scope || 'unknown'}'`)
            }
          })
        }
        if (PARALLEL > 1 && ((c % PARALLEL) !== SLICE)) {
          // parallel processing, skip slice
          return it.skip(`[${c % PARALLEL}/${PARALLEL}: skip] ${description}`, unit)
        }
        it(`[${c % PARALLEL}/${PARALLEL}: run] ${description}`, unit)
      })
    })
  })
})