const url = '/api/**/config/base/webservices';

module.exports = {
  id: 'configuration-webservices',
  description: 'Configuration - Web Services',
  tests: [
    {
      description: 'Webservices - Passthrough Form',
      url: '/configuration/webservices',
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