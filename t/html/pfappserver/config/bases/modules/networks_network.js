const url = '/api/**/config/base/network';

module.exports = {
  id: 'configuration-networks-network',
  description: 'Configuration - Networks network',
  tests: [
    {
      description: 'Networks network - Passthrough Form',
      url: '/configuration/network',
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