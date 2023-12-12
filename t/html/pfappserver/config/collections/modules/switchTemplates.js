const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const collection_url = 'configuration/switch_templates';
const resource_url = id => `/configuration/switch_template/${id}`;
const fixture = 'collections/switchTemplate.json';

module.exports = {
  id: 'switchTemplates',
  description: 'Switch Templates',
  tests: [
    {
      description: 'Switch Templates - Create New',
      scope: SCOPE_INSERT,
      fixture,
      url: collection_url,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New Switch Template)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/template_switches',
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
      description: 'Switch Templates - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/template_switch/**',
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
      description: 'Switch Templates - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/template_switch/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};