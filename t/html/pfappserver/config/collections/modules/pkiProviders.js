const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const types = {
  packetfence_local: 'Packetfence Local',
  packetfence_pki: 'Packetfence PKI',
  scep: 'SCEP PKI'
}

const tests = Object.entries(types).reduce((tests, [type, name]) => {
  const collection_url = '/configuration/pki_providers';
  const resource_url = (id) => `/configuration/pki_provider/${id}`;
  const fixture = `collections/pkiProvider/${type.toLowerCase()}.json`;

  return [...tests, ...[
    {
      description: `PKI Providers (${name}) - Create New`,
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      selectors: {
        buttonNewSelectors: [`button[type="button"]:contains(New PKI Provider)`, `ul li a[href$="/new/${type}"]`],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/pki_providers',
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
      description: `PKI Providers (${name}) - Update Existing`,
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/pki_provider/**',
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
      description: `PKI Providers (${name}) - Delete Existing`,
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/pki_provider/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]]
}, [])

module.exports = {
  id: 'pkiProviders',
  description: 'PKI Providers',
  tests
};