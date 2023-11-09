const { SCOPE_INSERT } = require('../config');
const url = '/configuration/roles';

module.exports = {
  id: 'roles',
  description: 'Roles',
  tests: [
    {
      description: 'Roles - Add New',
      scope: SCOPE_INSERT,
      url,
      form: {
        fixture: 'collections/role.json'
      },
      interceptors: [
        {
          method: 'POST', url: '/api/**/config/roles', expect: (req, fixture) => {
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