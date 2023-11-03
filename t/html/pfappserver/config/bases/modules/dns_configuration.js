const url = '/api/**/config/base/dns_configuration';

module.exports = {
  id: 'configuration-dns-configuration',
  description: 'Configuration - DNS configuration',
  tests: [
    {
      description: 'DNS configuration - Passthrough Form',
      url: '/configuration/dns',
      interceptors: [
        { method: 'GET', url, fixture: res => res.body.item },

        { method: '+(PATCH|PUT)', url, expect: (req, fixture) => {
          Object.keys(fixture).forEach(key => {
            expect(req.body).to.have.property(key)
            expect(req.body[key]).to.deep.equal(fixture[key], key)
          })
        } },
      ]
    },
  ]
};