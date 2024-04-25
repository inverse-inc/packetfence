/// <reference types="cypress" />

// API async w/ pfqueue polling,
// instead of poll tracking request chains, just wait a while and intercept final request
// TODO: improve intercepts w/ pfqueue polling
let waitForPfqueuePolling = { timeout: 300E3 } // 5 minutes (90 seconds is too short)

describe('Configurator', () => {

  before(() => {
    // cy.pfConfiguratorEnable()
  })

  beforeEach(() => {
    // interceptors - step 1
    cy.intercept('GET', '/api/**/config/interfaces?*').as('getInterfaces')
    cy.intercept('GET', '/api/**/config/interface/*').as('getInterface')
    cy.intercept('PATCH', '/api/**/config/interface/*').as('patchInterface')
    cy.intercept('PUT', '/api/**/config/system/hostname').as('setHostname')

    // interceptors - step 2
    cy.intercept('POST', '/api/**/config/base/database/test').as('getDatabase')
    cy.intercept('GET', '/api/**/config/base/general').as('getGeneral')
    cy.intercept('GET', '/api/**/config/base/alerting').as('getAlerting')
    cy.intercept('GET', '/api/**/user/admin').as('getAdminUser')
    cy.intercept('PATCH', '/api/**/user/admin/password').as('patchAdminPassword')

    // interceptors - step 3
    cy.intercept('GET', '/api/**/fingerbank/account_info').as('getFingerbankAccountInfo')

    // interceptors - Step 4
    cy.intercept('GET', '/api/**/config/base/advanced').as('getAdvanced')
    cy.intercept('GET', '/api/**/service/pf/status').as('getPacketfenceStatus')

    cy.visit('/')
   })

  it('SPA', () => {

    // assert URL redirect
    cy.url().should('include', '/admin#/configurator')

    /**
      * Step #1
     **/

    // URL path
    cy.url().should('include', '/configurator/network')

    // wizard circle is highlighted
    cy.get('.wizard-sidebar div.bg-warning, .wizard-sidebar div.btn-outline-primary').last().should('contain', '1')

    // wait for API
    cy.wait('@getInterfaces').its('response.statusCode').should('be.oneOf', [200])

    // next button is disabled
    cy.get('button[type="button"]:contains(Next Step)').should('have.attr', 'disabled', 'disabled')

    // interface table at least 2 rows, not contains 'management'
    cy.get('.card-body table.b-table tbody tr')
      .should('have.length.to.be.at.least', 2)
      .should('not.contain.text', 'management')

    // click the 2nd row of the interfaces table (index: 1)
    cy.get('.card-body table.b-table tbody tr').eq(1).click()

    // wait for API
    cy.wait('@getInterface').its('response.statusCode').should('be.oneOf', [200])

    // set the interface type to management
    cy.get('*[data-namespace="type"]').click() // open dropdown options
      .get('span.multiselect__option:contains(Management)').click() // select option

    // save the interface
    cy.get('button:contains(Save)').should('exist').click()

    // wait for API
    cy.wait('@patchInterface').its('response.statusCode').should('be.oneOf', [200])

    // wait for cancel button to be enabled,
    cy.get('button:contains(Cancel)').should('not.have.attr', 'disabled')

    // click and go back to interfaces list
    cy.get('button:contains(Cancel)').click()

    // wait for API
    cy.wait('@getInterfaces').its('response.statusCode').should('be.oneOf', [200])

    // interface table contains 'management'
    cy.get('.card-body table.b-table tbody tr').should('contain.text', 'management')

    // detect network button not exist
    cy.get('button:contains(Detect)').should('not.exist')

    // wait for form, then fill it out
    cy.get('.base-form').then(() => {
      cy.fixture('configurator').then(configurator => {
        cy.formFillNamespace('.base-form', configurator.network)
      })
    })

    // next button enabled
    cy.get('button[type="button"]:contains(Next Step)').should('not.have.attr', 'disabled')

    // click next button
    cy.get('button[type="button"]:contains(Next Step)').click()

    // wait for API
    cy.wait('@setHostname').its('response.statusCode').should('be.oneOf', [200])


    /**
      * Step #2
     **/

    // URL path
    cy.url().should('include', '/configurator/packetfence')

    // wizard circle is highlighted
    cy.get('.wizard-sidebar div.bg-warning, .wizard-sidebar div.btn-outline-primary').last().should('contain', '2')

    // wait for API
    cy.wait('@getDatabase').its('response.statusCode').should('be.oneOf', [200])
    cy.wait('@getGeneral').its('response.statusCode').should('be.oneOf', [200])
    cy.wait('@getAlerting').its('response.statusCode').should('be.oneOf', [200])
    cy.wait('@getAdminUser').its('response.statusCode').should('be.oneOf', [500])

    // next button is disabled
    cy.get('button[type="button"]:contains(Next Step)').should('have.attr', 'disabled', 'disabled')

    // automatic database enabled
    /*
    cy.get('*[data-form="database"] input[type="range"]').invoke('val').then(value => {
      expect(value).to.equal('1') // enabled
    })
    */

    // fill administrator form
    cy.fixture('configurator').then(configurator => {
      cy.formFillNamespace('*[data-form="administrator"]', configurator.administrator)
    })

    // next button enabled
    cy.get('button[type="button"]:contains(Next Step)').should('not.have.attr', 'disabled')

    // click next button
    cy.get('button[type="button"]:contains(Next Step)').click()

    // wait for API

    cy.wait('@patchAdminPassword', waitForPfqueuePolling).its('response.statusCode').should('be.oneOf', [200])


    /**
      * Step #3
     **/

    // URL path
    cy.url().should('include', '/configurator/fingerbank')

    // wizard circle is highlighted
    cy.get('.wizard-sidebar div.bg-warning, .wizard-sidebar div.btn-outline-primary').last().should('contain', '3')

    // wait for form, then fill it out
    cy.get('.base-form').then(() => {
      cy.fixture('configurator').then(configurator => {
        cy.formFillNamespace('.base-form', configurator.fingerbank)
        // verify fingerbank upstream api_key
        if (configurator.fingerbank['upstream.api_key']) {
          cy.get('button[type="button"]:contains(Verify)').click()
          cy.wait('@getFingerbankAccountInfo').its('response.statusCode').should('be.oneOf', [200])
        }
      })
    })

    // next button enabled
    cy.get('button[type="button"]:contains(Next Step)').should('not.have.attr', 'disabled')

    // click next button
    cy.get('button[type="button"]:contains(Next Step)').click()


    /**
      * Step #4
     **/

    // wait for API
    cy.wait('@getAdvanced').its('response.statusCode').should('be.oneOf', [200])

    // URL path
    cy.url().should('include', '/configurator/status')

    // wizard circle is highlighted
    cy.get('.wizard-sidebar div.bg-warning, .wizard-sidebar div.btn-outline-primary').last().should('contain', '4')

    // password match
    cy.fixture('configurator').then(configurator => {
      cy.get('*[data-card="administrator"] code').last().should('contain', configurator.administrator.password)
    })

    // click start button
    cy.get('button[type="submit"]:contains(Start)').click()

    // wait for API
    cy.wait('@getPacketfenceStatus', waitForPfqueuePolling).its('response.statusCode').should('be.oneOf', [200])


    /**
      * Complete
     **/

    // wait for URL path
    cy.url(waitForPfqueuePolling).should('include', '/login')

  })

})
