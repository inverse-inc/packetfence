const url = '/api/**/config/base/captive_portal';

module.exports = {
  id: 'configuration-captive-portal',
  description: 'Configuration - Captive Portal',
  tests: [
    {
      description: 'Captive Portal - Passthrough Form',
      url: '/configuration/captive_portal',
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