const { global, bases } = require('config');

describe('Bases', () => {
  Object.values(bases).forEach(base => {
    context(`Base - ${base.description}`, () => {
      beforeEach('Login as system', () => {
        cy.pfSystemLogin()
      })
      base.tests.forEach(test => {
        const { description, url, interceptors, form: { buttonSelector = 'button[type="submit"]' } = {} } = test
        it(description, () => {

          // storage from getter (fixture) to setter (expect)
          let cache = {}

          // setup API interceptors
          interceptors.forEach((interceptor, i) => {
            const { method, url, expect, timeout = 3E3 } = interceptor
            cy.intercept({ method, url }, (req) => {
              if (expect) {
                cy.window().then(() => {
                  expect(req, cache) // block
                })
              }
              else {
                req.continue() // passthrough
              }
            }).as(`interceptor${i}`)
          })

          // load page
          cy.visit(`${global.url}${url}`)

          interceptors.forEach(async (interceptor, i) => {
            const { url, fixture, timeout = 10E3 } = interceptor
            if (fixture) {
              await cy.wait(`@interceptor${i}`, { timeout })
                .then(interception => {
                  const response = interception.response
                  cache = fixture(response) || response
                })
            }
          })

          // click button
          cy.get(buttonSelector).first().as('button')
          cy.get('@button')
            .should('not.have.class', 'disabled')
            .and('not.have.disabled', 'disabled')
            .click()
        })
      })
    })
  })
});