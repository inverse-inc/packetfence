const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const collection_url = 'configuration/syslog';
const resource_url = id => `/configuration/syslog/${id}`;
const fixture = 'collections/syslogForwarder.json';

module.exports = {
  id: 'syslogForwarders',
  description: 'Syslog Forwarders',
  tests: [
    {
      description: 'Syslog Forwarders - Create New',
      scope: SCOPE_INSERT,
      fixture,
      url: collection_url,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New Syslog Entry)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/syslog_forwarders',
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
      description: 'Syslog Forwarders - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/syslog_forwarder/**',
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
      description: 'Syslog Forwarders - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/syslog_forwarder/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};