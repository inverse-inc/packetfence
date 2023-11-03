const url = '/api/**/config/base/services';

module.exports = {
  id: 'configuration-services',
  description: 'Configuration - Services',
  tests: [
    {
      description: 'Services - Passthrough Form',
      url: '/configuration/services',
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