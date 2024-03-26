const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');
const countries = require('../../../config/global/countries');
const { digests, keyTypes } = require('../../../config/global/pki');

const collection_url = 'configuration/pki/cas';
const resource_url = id => `/configuration/pki/ca/${id}`;
const fixture = 'collections/pki/ca.json';

const map = (value, namespace = '') => {
  if (namespace === 'country') { // remap country
    return countries.default[value]
  }
  if (namespace === 'digest') { // remap digest
    return digests[value]
  }
  if (namespace === 'key_type') { // remap key_type
    return keyTypes[value]
  }
  return value
}

module.exports = {
  id: 'pkiCas',
  description: 'PKI Certificate Authorities',
  tests: [
    {
      description: 'PKI Certificate Authorities - Create New',
      scope: SCOPE_INSERT,
      fixture,
      map,
      url: collection_url,
      selectors: {
        buttonNewSelectors: ['button[type="button"]:contains(New Certificate Authority)'],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/pki/cas',
          expectRequest: (request, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(request.body).to.have.property(key)
              expect(request.body[key]).to.deep.equal(fixture[key], key)
            })
          },
          expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
            const { body: { items: { 0: { ID } = {} } = {} } = {} } = response
            return { ID } // push `id` to fixture
          }
        }
      ]
    },
    {
      description: 'PKI Certificate Authorities - Resign Existing',
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      idFrom: (_, cache) => cache.ID,
      selectors: {
        buttonDeleteSelector: 'button[type="button"]:contains(Re-Sign)',
        buttonDeleteConfirmSelector: 'button[type="button"][data-confirm]:contains(Re-Sign)'
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/pki/ca/resign/**',
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
    }
  ]
};