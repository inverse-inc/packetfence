const url = '/api/**/config/base/database_proxysql';

module.exports = {
  id: 'configuration-database-proxysql',
  description: 'Configuration - Database ProxySQL',
  tests: [
    {
      description: 'Database ProxySQL - Passthrough Form',
      url: '/configuration/database_proxysql',
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