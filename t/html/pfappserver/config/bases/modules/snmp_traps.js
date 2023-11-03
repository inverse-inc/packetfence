const url = '/api/**/config/base/snmp_traps';

module.exports = {
  id: 'configuration-snmp-traps',
  description: 'Configuration - SNMP Traps',
  tests: [
    {
      description: 'SNMP Traps - Passthrough Form',
      url: '/configuration/snmp_traps',
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