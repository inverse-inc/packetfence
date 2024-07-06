const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const collection_url = 'configuration/radius/ssl';
const resource_url = id => `/configuration/radius/ssl/${id}`;
const fixture = 'collections/radius/ssl.json';

module.exports = {
  id: 'radiusSslCertificates',
  description: 'RADIUS SSL Certificates',
  tests: [
    {
      description: 'RADIUS SSL Certificates - Create New',
      scope: SCOPE_INSERT,
      fixture,
      url: collection_url,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New SSL Certificate)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/ssl_certificates',
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
      description: 'RADIUS SSL Certificates - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/ssl_certificate/**',
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
      description: 'RADIUS SSL Certificates - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/ssl_certificate/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};