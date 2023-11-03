const url = '/api/**/config/base/alerting';

module.exports = {
  id: 'configuration-alerting',
  description: 'Configuration - Alerting',
  tests: [
    {
      description: 'Alerting - Passthrough Form',
      url: '/configuration/alerting',
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