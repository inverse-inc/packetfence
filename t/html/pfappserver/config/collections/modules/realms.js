const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const collection_url = '/configuration/realms';
const resource_url = id => `/configuration/realm/${id}`;
const fixture = 'collections/realm.json';

module.exports = {
  id: 'realms',
  description: 'Realms',
  tests: [
    {
      description: 'Realms - Create New',
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      interceptors: [
        {
          method: 'POST', url: '/api/**/config/realms', expectRequest: (request, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(request.body).to.have.property(key)
              expect(request.body[key]).to.deep.equal(fixture[key], key)
            })
          }
        }
      ]
    },
    {
      description: 'Realms - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/realm/**',
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
      description: 'Realms - Delete Existing',
      scope: SCOPE_DELETE,
      url: resource_url,
      fixture,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/realm/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    },
  ]
};