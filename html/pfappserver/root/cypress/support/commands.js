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
  cy.readFile('/usr/local/pf/conf/unified_api_system_pass').then((password) => {
    cy.request('POST', '/api/v1/login', { username: 'system', password }).then((response) => {
      window.localStorage.setItem('user-token', response.body.token)
    })
  })
})

Cypress.Commands.add('pfLogout', () => {
  window.localStorage.removeItem('user-token')
})
