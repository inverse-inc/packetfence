const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const collection_url = 'configuration/fingerbank/mac_vendors';
const resource_url = id => `/configuration/fingerbank/local/mac_vendor/${id}`;
const fixture = 'collections/fingerbank/macVendor.json';

module.exports = {
  id: 'fingerbankMacVendors',
  description: 'Fingerbank MAC Vendors',
  tests: [
    {
      description: 'Fingerbank MAC Vendors - Create New',
      scope: SCOPE_INSERT,
      fixture,
      url: collection_url,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New MAC Vendor)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/fingerbank/local/mac_vendors',
          expectRequest: (request, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(request.body).to.have.property(key)
              expect(request.body[key]).to.deep.equal(fixture[key], key)
            })
          },
          expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
            return response.body // push `id` to fixture
          }
        }
      ]
    },
    {
      description: 'Fingerbank MAC Vendors - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      idFrom: (_, cache) => cache.id,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/fingerbank/local/mac_vendor/**',
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
      description: 'Fingerbank MAC Vendors - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      idFrom: (_, cache) => cache.id,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/fingerbank/local/mac_vendor/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};