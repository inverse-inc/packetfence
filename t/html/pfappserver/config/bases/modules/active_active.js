const url = '/api/**/config/base/active_active';

module.exports = {
  id: 'configuration-active-active',
  description: 'Configuration - Active active',
  tests: [
    {
      description: 'Active active - Passthrough Form',
      url: '/configuration/active_active',
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