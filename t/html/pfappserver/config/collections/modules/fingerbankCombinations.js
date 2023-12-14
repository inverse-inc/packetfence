const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const { oses } = require('../../../config/global/fingerbank');

const collection_url = 'configuration/fingerbank/combinations';
const resource_url = id => `/configuration/fingerbank/local/combination/${id}`;
const fixture = 'collections/fingerbank/combination.json';

const map = (value, namespace = '') => {
  if (namespace === 'device_id') { // remap device_id
    return oses[value]
  }
  return value
}

module.exports = {
  id: 'fingerbankCombinations',
  description: 'Fingerbank Combinations',
  tests: [
    {
      description: 'Fingerbank Combinations - Create New',
      scope: SCOPE_INSERT,
      fixture,
      map,
      url: collection_url,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New Combination)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/fingerbank/local/combinations',
          expectRequest: (request, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(request.body).to.have.property(key)
              expect(request.body[key]).to.deep.equal(fixture[key], key)
            })
          },
          expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
            return response.body // push `id` to fixture
          }
        }
      ]
    },
    {
      description: 'Fingerbank Combinations - Update Existing',
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      idFrom: (_, cache) => cache.id,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/fingerbank/local/combination/**',
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
      description: 'Fingerbank Combinations - Delete Existing',
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      idFrom: (_, cache) => cache.id,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/fingerbank/local/combination/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]
};