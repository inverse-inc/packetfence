const url = '/api/**/config/base/admin_login';

module.exports = {
  id: 'configuration-admin-login',
  description: 'Configuration - Admin login',
  tests: [
    {
      description: 'Admin login - Passthrough Form',
      url: '/configuration/admin_login',
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