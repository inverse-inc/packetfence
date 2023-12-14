const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const collection_url = 'configuration/fingerbank/dhcp_fingerprints';
const resource_url = id => `/configuration/fingerbank/local/dhcp_fingerprint/${id}`;
const fixture = 'collections/fingerbank/dhcpFingerprint.json';

module.exports = {
  id: 'fingerbankDhcpFingerprints',
  description: 'Fingerbank DHCP Fingerprints',
  tests: [
    {
      description: 'Fingerbank DHCP Fingerprints - Create New',
      scope: SCOPE_INSERT,
      fixture,
      url: collection_url,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New DHCP Fingerprint)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/fingerbank/local/dhcp_fingerprints',
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
      description: 'Fingerbank DHCP Fingerprints - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      idFrom: (_, cache) => cache.id,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/fingerbank/local/dhcp_fingerprint/**',
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
      description: 'Fingerbank DHCP Fingerprints - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      idFrom: (_, cache) => cache.id,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/fingerbank/local/dhcp_fingerprint/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};