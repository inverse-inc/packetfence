const url = '/api/**/config/base/parking';

module.exports = {
  id: 'configuration-networks-parking',
  description: 'Configuration - Networks parking',
  tests: [
    {
      description: 'Networks parking - Passthrough Form',
      url: '/configuration/parking',
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