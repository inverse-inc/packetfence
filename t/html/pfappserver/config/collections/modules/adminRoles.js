const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const collection_url = 'configuration/admin_roles';
const resource_url = id => `/configuration/admin_role/${id}`;

const fixture = 'collections/adminRole.json';

const acls = require('../../../cypress/fixtures/runtime/acls.json');
const map = (value, namespace = '') => {
  if (namespace === 'actions') { // re-map actions
    return value.map(v => acls[v])
  }
  return value
}

module.exports = {
  id: 'adminRoles',
  description: 'Admin Roles',
  tests: [
    {
      description: 'Admin Roles - Create New',
      scope: SCOPE_INSERT,
      fixture,
      map,
      url: collection_url,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New Admin Role)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/admin_roles',
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
      description: 'Admin Roles - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/admin_role/**',
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
      description: 'Admin Roles - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/admin_role/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};