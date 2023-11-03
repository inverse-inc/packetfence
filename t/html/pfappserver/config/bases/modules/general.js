const url = '/api/**/config/base/general';

module.exports = {
  id: 'configuration-general',
  description: 'Configuration - General',
  tests: [
    {
      description: 'General - Passthrough Form',
      url: '/configuration/general',
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