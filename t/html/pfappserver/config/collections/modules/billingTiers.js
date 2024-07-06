const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const collection_url = '/configuration/billing_tiers';
const resource_url = id => `/configuration/billing_tier/${id}`;

const fixture = 'collections/billingTier.json';
const flatten = true;

const map = (value, namespace = '') => {
  if (namespace.endsWith('.unit')) { // re-map access durations
      switch (value) {
        case 's': return 'second'
        case 'm': return 'minute'
        case 'h': return 'hour'
        case 'D': return 'day'
        case 'W': return 'week'
        case 'M': return 'month'
        case 'Y': return 'year'
      }
  }
  return value
}

module.exports = {
  id: 'billingTiers',
  description: 'Billing Tiers',
  tests: [
    {
      description: 'Billing Tiers - Create New',
      scope: SCOPE_INSERT,
      fixture,
      flatten,
      map,
      url: collection_url,
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/billing_tiers',
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
      description: 'Billing Tiers - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      flatten,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/billing_tier/**',
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
      description: 'Billing Tiers - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      flatten,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/billing_tier/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};