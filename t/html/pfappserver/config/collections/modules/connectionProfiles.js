const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const collection_url = '/configuration/connection_profiles';
const resource_url = id => `/configuration/connection_profile/${id}`;

const fixture = 'collections/connectionProfile.json';
const flatten = true;

module.exports = {
  id: 'connectionProfiles',
  description: 'Connection Profiles',
  tests: [
    {
      description: 'Connection Profiles - Create New',
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      flatten,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New Connection Profile)'],
      },
      beforeFormFill: (selector, options) => { // "filter" required
        cy.get(selector, options).then($selector => {
          const buttonSelector = `button[type="button"]:contains(Add Filter)`
          if ($selector.find(buttonSelector).length) {
            cy.get(buttonSelector, options).each((button, n) => {
              // click button
              cy.get(button, options)
                .click({ log: true })
            })
          }
        })
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/connection_profiles',
          expectRequest: (request, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(request.body).to.have.property(key)
              expect(request.body[key]).to.deep.equal(fixture[key], key)
            })
          },
          expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(201)
          }
        }
      ]
    },
    {
      description: 'Connection Profiles - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      flatten,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/connection_profile/**',
          expectRequest: (request, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(request.body).to.have.property(key)
              expect(request.body[key]).to.deep.equal(fixture[key], key)
            })
          },
          expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    },
    {
      description: 'Connection Profiles - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      flatten,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/connection_profile/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};