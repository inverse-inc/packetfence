const url = '/api/**/config/base/advanced';

module.exports = {
  id: 'configuration-active-active',
  description: 'Configuration - Advanced',
  tests: [
    {
      description: 'Advanced - Passthrough Form',
      url: '/configuration/advanced',
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