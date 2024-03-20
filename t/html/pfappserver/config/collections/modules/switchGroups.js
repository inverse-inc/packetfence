const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const collection_url = '/configuration/switch_groups';
const resource_url = id => `/configuration/switch_group/${id}`;
const fixture = 'collections/switchGroup.json';
const timeout = 10E3;

module.exports = {
  id: 'switchGroups',
  description: 'Switch Groups',
  tests: [
    {
      description: 'Switch Groups - Create New',
      scope: SCOPE_INSERT,
      url: collection_url,
      timeout,
      fixture,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New Switch Group)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/switch_groups',
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
      description: 'Switch Groups - Update Existing',
      scope: SCOPE_UPDATE,
      timeout,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/switch_group/**',
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
      description: 'Switch Groups - Delete Existing',
      scope: SCOPE_DELETE,
      timeout,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/switch_group/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};