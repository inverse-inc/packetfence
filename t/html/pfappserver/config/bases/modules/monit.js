const url = '/api/**/config/base/monit';

module.exports = {
  id: 'configuration-monit',
  description: 'Configuration - Monit',
  tests: [
    {
      description: 'Monit - Passthrough Form',
      url: '/configuration/monit',
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