const url = '/api/**/config/base/inline';

module.exports = {
  id: 'configuration-networks-inline',
  description: 'Configuration - Networks inline',
  tests: [
    {
      description: 'Networks inline - Passthrough Form',
      url: '/configuration/inline',
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