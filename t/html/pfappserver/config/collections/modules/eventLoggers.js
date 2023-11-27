const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const types = {
  syslog: 'Syslog'
};


const tests = Object.entries(types).reduce((tests, [type, name]) => {
  const collection_url = '/configuration/event_loggers';
  const resource_url = (id) => `/configuration/event_logger/${id}`;
  const fixture = `collections/eventLogger/${type.toLowerCase()}.json`;

  return [...tests, ...[
    {
      description: `Event Loggers (${name}) - Create New`,
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      selectors: {
        buttonNewSelectors: [`button[type="button"]:contains(New Event Logger)`, `ul li a[href$="/new/${type}"]`],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/event_loggers',
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
      description: `Event Loggers (${name}) - Update Existing`,
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/event_logger/**',
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
      description: `Event Loggers (${name}) - Delete Existing`,
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/event_logger/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]]
}, [])

module.exports = {
  id: 'eventLoggers',
  description: 'Event Loggers',
  tests
};