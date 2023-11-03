const url = '/api/**/config/base/database_advanced';

module.exports = {
  id: 'configuration-database-advanced',
  description: 'Configuration - Database advanced',
  tests: [
    {
      description: 'Database advanced - Passthrough Form',
      url: '/configuration/database_advanced',
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