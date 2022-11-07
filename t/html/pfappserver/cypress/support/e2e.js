require('./commands')

// > Cannot set properties of undefined (setting 'Vue')
Cypress.on('uncaught:exception', (err, runnable) => {
  // returning false here prevents Cypress from
  // failing the test
  return false
})