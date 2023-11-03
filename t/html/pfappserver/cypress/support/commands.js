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
    return cy.request('POST', '/api/v1/login', { username: 'system', password }).then(response => {
      return window.localStorage.setItem('user-token', response.body.token)
    })
  })
})

Cypress.Commands.add('pfLogout', () => {
  return window.localStorage.removeItem('user-token')
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

Cypress.Commands.add('formFillNamespace', (data, element) => {
  (element || cy.get('form').first()).within($ => {
    for (let entry of Object.entries(data)) {
      const [namespace, value] = entry
      const selector = `*[data-namespace="${namespace}"]:not([disabled])`
      if ($.find(selector).length) {
        cy.get(selector)
          .then(el => {
            const e =  Cypress.$(el)[0]
            const tagName = e.tagName.toLowerCase()
            const type = e.getAttribute('type')
            switch (true) {
              case tagName === 'input' && ['text', 'password'].includes(type):
              case tagName === 'textarea':
                  cy.get(el).type(`{selectAll}{del}${value}`)
                break
              case tagName === 'input' && ['range'].includes(type):
                  // TODO
                break
              default:
                throw new Error(`unhandled element <${tagName} type="${type||''}" data-namespace="${namespace}" />`)
            }
          })
      }
      else {
        cy.task('error', `empty selector ${selector}`)
      }
    }
  })
})
