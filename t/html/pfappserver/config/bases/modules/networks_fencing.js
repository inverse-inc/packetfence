const url = '/api/**/config/base/fencing';

module.exports = {
  id: 'configuration-networks-fencing',
  description: 'Configuration - Networks fencing',
  tests: [
    {
      description: 'Networks fencing - Passthrough Form',
      url: '/configuration/fencing',
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