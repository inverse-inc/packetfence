const url = '/api/**/config/base/guests_admin_registration';

module.exports = {
  id: 'configuration-access-durations',
  description: 'Configuration - Access durations',
  tests: [
    {
      description: 'Access durations - Passthrough Form',
      url: '/configuration/access_duration',
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