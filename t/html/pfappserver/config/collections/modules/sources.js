const { SCOPE_INSERT, SCOPE_UPDATE, SCOPE_DELETE } = require('../config');

const typeCategories = {
  INTERNAL: 'Internal',
  EXTERNAL: 'External',
  EXCLUSIVE: 'Exclusive',
  BILLING: 'Billing'
}

const typesByCategory = {
  [typeCategories.INTERNAL]: [
    'AD',
    'Authorization',
    'AzureAD',
    'EAPTLS',
    'EDIR',
    'Htpasswd',
    'GoogleWorkspaceLDAP',
    'HTTP',
    'Kerberos',
    'LDAP',
//    'Potd', // Issue #TODO
    'RADIUS',
    'SAML'
  ],
  [typeCategories.EXTERNAL]: [
    'Clickatell',
    'Email',
    'Facebook',
    'Github',
    'Google',
    'Kickbox',
    'LinkedIn',
    'Null',
    'OpenID',
    'SMS',
    'SponsorEmail',
    'Twilio',
    'WindowsLive'
  ],
  [typeCategories.EXCLUSIVE]: [
    'AdminProxy',
    'Blackhole',
    'Eduroam',
  ],
  [typeCategories.BILLING]: [
    'Paypal',
    'Stripe'
  ]
};

const types = Object.entries(typesByCategory).reduce((types, [category, categoryTypes]) => {
  return [ ...types, ...categoryTypes.map(type => ({ [type]: category })) ]
}, [])

const tests = types.reduce((tests, typeCategory) => {
  const { 0: [type, category] }  = Object.entries(typeCategory)
  const collection_url = '/configuration/sources';
  const resource_url = (id) => `/configuration/source/${id}`;
  const fixture = `collections/source/${type.toLowerCase()}.json`;

  return [...tests, ...[
    {
      description: `Sources (${category}/${type}) - Create New`,
      scope: SCOPE_INSERT,
      url: collection_url,
      fixture,
      selectors: {
        buttonNewSelectors: [`button[type="button"]:contains(New ${category.toLowerCase()})`, `ul li a[href$="/new/${type}"]`],
      },
      interceptors: [
        {
          method: 'POST',
          url: '/api/**/config/sources',
          expectRequest: (request, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(request.body).to.have.property(key)
              expect(request.body[key]).to.deep.equal(fixture[key], key)
            })
          },
          expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(201)
          }
        }
      ]
    },
    {
      description: `Sources (${category}/${type}) - Update Existing`,
      scope: SCOPE_UPDATE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/source/**',
          expectRequest: (request, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(request.body).to.have.property(key)
              expect(request.body[key]).to.deep.equal(fixture[key], key)
            })
          },
          expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    },
    {
      description: `Sources (${category}/${type}) - Delete Existing`,
      scope: SCOPE_DELETE,
      fixture,
      url: resource_url,
      interceptors: [
        {
          method: 'DELETE', url: '/api/**/config/source/**', expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  ]]
}, [])

module.exports = {
  id: 'sources',
  description: 'Sources',
  tests
};