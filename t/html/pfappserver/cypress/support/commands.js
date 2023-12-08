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

Cypress.Commands.add('formFillNamespace', (data, selector = 'body') => {
  return cy.get(selector)
    .should('exist')
    .get('*[data-namespace]')
    .should("have.length.gte", 0)
    .each(element => {
      const namespace = element.attr('data-namespace')
      const chosen = element.attr('data-chosen')
      if (namespace in data && data[namespace]) {
        const value = data[namespace]
        const type = element.attr('type')
        const e = Cypress.$(element)[0]
        const tagName = e.tagName.toLowerCase()
        switch (true) {
          case tagName === 'input' && ['text', 'password', 'number'].includes(type):
          case tagName === 'textarea':
            cy.get(e).as(namespace)
            cy.get(`@${namespace}`)
              .clear({ log: true, force: true })
              .type(value, { log: true, force: true })
            break
          case tagName === 'input' && ['range'].includes(type):
            // TODO
            break
          case tagName === 'div' && !!chosen:
            cy.get(e).within(() => {
              const values = ((Array.isArray(value)) ? value : [value]).reduce((values, _value) => {
                return `${values}${_value}{enter}`
              }, '')
              cy.get('input.multiselect__input').as(namespace)
              cy.get(`@${namespace}`)
                .clear({ log: true, force: true })
                .type(values, { log: true, force: true })
            })
            break
          default:
            throw new Error(`unhandled element <${tagName} type="${type || ''}" data-chosen="${chosen}" data-namespace="${namespace}" />`)
        }
      }
    })
})
