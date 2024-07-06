const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const types = {
  accept: 'Accept',
  airwatch: 'Airwatch',
  android: 'Android',
  deny: 'Deny',
  dpsk: 'DPSK',
  jamf: 'Jamf',
  kandji: 'Kandji',
  mobileconfig: 'Apple Devices',
  mobileiron: 'Mobileiron',
  sentinelone: 'SentinelOne',
  windows: 'Windows',
  intune: 'Microsoft Intune',
  google_workspace_chromebook: 'Google Workspace Chromebook'
};

const tests = Object.entries(types).reduce((tests, [type, name]) => {
  const collection_url = '/configuration/provisionings';
  const resource_url = (id) => `/configuration/provisioning/${id}`;
  const fixture = `collections/provisioning/${type.toLowerCase()}.json`;

  return [...tests, ...[
    {
      description: `Provisionings (${name}) - Create New`,
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      selectors: {
        buttonNewSelectors: [`button[type="button"]:contains(New Provisioner)`, `ul li a[href$="/new/${type}"]`],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/provisionings',
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
      description: `Provisionings (${name}) - Update Existing`,
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/provisioning/**',
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
      description: `Provisionings (${name}) - Delete Existing`,
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/provisioning/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]]
}, [])

module.exports = {
  id: 'provisionings',
  description: 'Provisionings',
  tests
};