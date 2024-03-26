const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const types = {
  BarracudaNG: 'BarracudaNG',
  Checkpoint: 'Checkpoint',
  ContentKeeper: 'ContentKeeper',
  CiscoIsePic: 'Cisco ISE-PIC',
  FamilyZone: 'FamilyZone',
  FortiGate: 'FortiGate',
  Iboss: 'Iboss',
  JSONRPC: 'JSONRPC',
  JuniperSRX: 'JuniperSRX',
  LightSpeedRocket: 'LightSpeedRocket',
  PaloAlto: 'PaloAlto',
  SmoothWall: 'SmoothWall',
  WatchGuard: 'WatchGuard'
};

const tests = Object.entries(types).reduce((tests, [type, name]) => {
  const collection_url = '/configuration/firewalls';
  const resource_url = (id) => `/configuration/firewall/${id}`;
  const fixture = `collections/firewall/${type.toLowerCase()}.json`;

  return [...tests, ...[
    {
      description: `Firewalls (${name}) - Create New`,
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      selectors: {
        buttonNewSelectors: [`button[type="button"]:contains(New Firewall)`, `ul li a[href$="/new/${type}"]`],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/firewalls',
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
      description: `Firewalls (${name}) - Update Existing`,
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/firewall/**',
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
      description: `Firewalls (${name}) - Delete Existing`,
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/firewall/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]]
}, [])

module.exports = {
  id: 'firewalls',
  description: 'Firewalls',
  tests
};