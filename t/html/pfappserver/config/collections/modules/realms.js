const { SCOPE_INSERT, SCOPE_DELETE } = require('../config');
const collection_url = '/configuration/realms';
const resource_url = id => `/configuration/realm/${id}`;
const fixture = 'collections/realm.json';

module.exports = {
  id: 'realms',
  description: 'Realms',
  tests: [
    {
      description: 'Realms - Add New',
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      interceptors: [
        {
          method: 'POST', url: '/api/**/config/realms', expectRequest: (req, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(req.body).to.have.property(key)
              expect(req.body[key]).to.deep.equal(fixture[key], key)
            })
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