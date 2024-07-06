const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const collection_url = 'configuration/wrix';
const resource_url = id => `/configuration/wrix/${id}`;
const fixture = 'collections/wrix.json';

module.exports = {
  id: 'wrixLocations',
  description: 'WRIX Locations',
  tests: [
    {
      description: 'WRIX Locations - Create New',
      scope: SCOPE_INSERT,
      fixture,
      url: collection_url,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New WRIX Location)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/wrix_locations',
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
      description: 'WRIX Locations - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/wrix_location/**',
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
      description: 'WRIX Locations - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/wrix_location/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};