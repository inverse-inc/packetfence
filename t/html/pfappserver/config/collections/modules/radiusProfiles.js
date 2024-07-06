const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const types = { // singular, 's' is appended for plural
  eap: 'EAP Profile',
  tls: 'TLS Profile',
  fast: 'Fast Profile',
  ocsp: 'OCSP Profile'
};


const tests = Object.entries(types).reduce((tests, [type, name]) => {
  const collection_url = `/configuration/radius/${type}`;
  const resource_url = (id) => `/configuration/radius/${type}/${id}`;
  const fixture = `collections/radius/${type.toLowerCase()}.json`;

  return [...tests, ...[
    {
      description: `RADIUS Profiles (${name}) - Create New`,
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      selectors: {
        buttonNewSelectors: [`button[type="button"]:contains(New ${name})`],
        tabSelector: false,
      },
      interceptors: [
        {
          method: 'POST',
          url: `/api/**/config/radiusd/${type}_profiles`,
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
      description: `RADIUS Profiles (${name}) - Update Existing`,
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: `/api/**/config/radiusd/${type}_profile/**`,
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
      description: `RADIUS Profiles (${name}) - Delete Existing`,
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: `/api/**/config/radiusd/${type}_profile/**`, expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]]
}, [])

module.exports = {
  id: 'radiusProfiles',
  description: 'RADIUS Profiles',
  tests
};