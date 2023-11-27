const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const types = {
  dhcp: 'DHCP',
  fortianalyser: 'FortiAnalyzer',
  nexpose: 'Nexpose',
  regex: 'Regex',
  security_onion: 'Security Onion',
  snort: 'Snort',
  suricata: 'Suricata',
  suricata_md5: 'Suricata MD5'
};


const tests = Object.entries(types).reduce((tests, [type, name]) => {
  const collection_url = '/configuration/pfdetect';
  const resource_url = (id) => `/configuration/pfdetect/${id}`;
  const fixture = `collections/syslogParser/${type.toLowerCase()}.json`;

  return [...tests, ...[
    {
      description: `Syslog Parsers (${name}) - Create New`,
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      selectors: {
        buttonNewSelectors: [`button[type="button"]:contains(New Syslog Parser)`, `ul li a[href$="/new/${type}"]`],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/syslog_parsers',
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
      description: `Syslog Parsers (${name}) - Update Existing`,
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/syslog_parser/**',
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
      description: `Syslog Parsers (${name}) - Delete Existing`,
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/syslog_parser/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]]
}, [])

module.exports = {
  id: 'syslogParsers',
  description: 'Syslog Parsers',
  tests
};