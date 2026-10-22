Cypress.Commands.add('pfSystemLogin', () => {
  /*
  cy.visit('https://localhost:1443/admin#/login').then(() => {
    cy.readFile('/usr/local/pf/conf/unified_api_system_pass').then((password) => {
      cy.get('form input#username').first().type('system')
      cy.get('form input#password').first().type(password)
      cy.get('form button[type="submit"]').first().click()
    })
  })
  */
  return cy.pfUnifiedSystemPassword().then(password => {
    // Cookie auth: /api/v1/login sets the HttpOnly `token` cookie, which Cypress
    // keeps in its shared cookie jar for subsequent SPA requests. No localStorage.
    return cy.request('POST', '/api/v1/login', { username: 'system', password })
  })
})

Cypress.Commands.add('pfLogout', () => {
  return cy.request({ method: 'POST', url: '/api/v1/logout', failOnStatusCode: false })
})

Cypress.Commands.add('pfUnifiedSystemPassword', () => {
  return cy.readFile('/usr/local/pf/conf/unified_api_system_pass')
})

Cypress.Commands.add('requestAsSystem', request => {
  return cy.readFile('/usr/local/pf/conf/unified_api_system_pass').then(password => {
    return cy.request('POST', '/api/v1/login', { username: 'system', password }).then(response => {
      const { headers = {} } = request
      return cy.request({ ...request, headers: { ...headers, Authorization: `Bearer ${response.body.token}` } })
    })
  })
})

Cypress.Commands.add('pfConfiguratorEnable', () => {
  return cy.requestAsSystem({
    method: 'PATCH',
    url: '/api/v1/config/base/advanced',
    body: {
      id: 'advanced',
      configurator: 'enabled'
    }
  })
})

Cypress.Commands.add('pfConfiguratorDisable', () => {
  return cy.requestAsSystem({
    method: 'PATCH',
    url: '/api/v1/config/base/advanced',
    body: {
      id: 'advanced',
      configurator: 'disabled'
    }
  })
})

Cypress.Commands.add('formFillNamespace', (selector, data) => {
  cy.get(selector).then($ => {
    for (let entry of Object.entries(data)) {
      const [namespace, value] = entry
      cy.get(`${selector} *[data-namespace="${namespace}"]:not([disabled])`).first().then(el => {
        const tagName = Cypress.$(el)[0].tagName.toLowerCase()
        switch (tagName) {
          case "input":
            cy.get(el).type(`{selectAll}{del}${value}`)
            break
          default:
            throw new Error(`unhandled form tagName "${tagName}"`)
        }
      })
    }
  })
})
