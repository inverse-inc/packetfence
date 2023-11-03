const url = '/api/**/config/base/database';

module.exports = {
  id: 'configuration-database-general',
  description: 'Configuration - Database general',
  tests: [
    {
      description: 'Database general - Passthrough Form',
      url: '/configuration/database_general',
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