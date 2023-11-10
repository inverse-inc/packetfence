const { SCOPE_INSERT } = require('../config');
const url = '/configuration/realms';

module.exports = {
  id: 'realms',
  description: 'Realms',
  tests: [
    {
      description: 'Realms - Add New',
      scope: SCOPE_INSERT,
      url,
      form: {
        fixture: 'collections/realm.json'
      },
      interceptors: [
        {
          method: 'POST', url: '/api/**/config/realms', expect: (req, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(req.body).to.have.property(key)
              expect(req.body[key]).to.deep.equal(fixture[key], key)
            })
          }
        }
      ]
    },
  ]
};