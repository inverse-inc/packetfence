const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const types = { // singular, 's' is appended for plural
  dhcp_filter: 'DHCP Filter',
  dns_filter: 'DNS Filter',
  radius_filter: 'RADIUS Filter',
  switch_filter: 'Switch Filter',
  vlan_filter: 'VLAN Filter'
};


const tests = Object.entries(types).reduce((tests, [type, name]) => {
  const collection_url = `/configuration/filter_engines/${type}s`;
  const resource_url = (id) => `/configuration/filter_engines/${type}s/${id}`;
  const fixture = `collections/filterEngine/${type.toLowerCase()}.json`;

  return [...tests, ...[
    {
      description: `Filter Engines (${name}) - Create New`,
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      selectors: {
        buttonNewSelectors: [`button[type="button"]:contains(New Filter)`],
        tabSelector: false,
      },
      interceptors: [
        {
          method: 'POST',
          url: `/api/**/config/filter_engines/${type}s`,
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
      description: `Filter Engines (${name}) - Update Existing`,
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: `/api/**/config/filter_engines/${type}/**`,
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
      description: `Filter Engines (${name}) - Delete Existing`,
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: `/api/**/config/filter_engines/${type}/**`, expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]]
}, [])

module.exports = {
  id: 'filterEngines',
  description: 'Filter Engines',
  tests
};