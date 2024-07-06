const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const collection_url = 'configuration/fingerbank/dhcpv6_fingerprints';
const resource_url = id => `/configuration/fingerbank/local/dhcpv6_fingerprint/${id}`;
const fixture = 'collections/fingerbank/dhcpv6Fingerprint.json';

module.exports = {
  id: 'fingerbankDhcpv6Fingerprints',
  description: 'Fingerbank DHCPv6 Fingerprints',
  tests: [
    {
      description: 'Fingerbank DHCPv6 Fingerprints - Create New',
      scope: SCOPE_INSERT,
      fixture,
      url: collection_url,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New DHCPv6 Fingerprint)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/fingerbank/local/dhcp6_fingerprints',
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
      description: 'Fingerbank DHCPv6 Fingerprints - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      idFrom: (_, cache) => cache.id,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/fingerbank/local/dhcp6_fingerprint/**',
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
      description: 'Fingerbank DHCPv6 Fingerprints - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      idFrom: (_, cache) => cache.id,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/fingerbank/local/dhcp6_fingerprint/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};