const global = require('./global')
const bases = require('./bases')
const collections = require('./collections')

const latencyInterceptor = (url = `${global.url}**`, setDelayMs = 1E3) => {
  cy.intercept({ url, middleware: true, }, req => Cypress.Promise.delay(setDelayMs).then(req.reply))
}

module.exports = {
  global,
  bases,
  collections,

  latencyInterceptor,
}