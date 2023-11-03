const expectByType = (type, req, fixture) => {
  if (type in fixture) {
    Object.keys(fixture[type]).forEach(key => {
      expect(req.body).to.have.property(key)
      expect(req.body[key]).to.deep.equal(fixture[type][key], key)
    })
  }
};

module.exports = {
  id: 'configuration-fingerbank-general-settings',
  description: 'Configuration - Fingerbank',
  tests: [
    {
      description: 'General Settings - Passthrough Form',
      url: '/configuration/fingerbank/general_settings',
      interceptors: [
        { method: 'GET', url: '/api/**/config/fingerbank_settings?*', fixture: res => res.body.items.reduce((fixture, { id, ...rest }) => ({ ...fixture, [id]: { id, ...rest } }), {}) },

        { method: '+(PATCH|PUT)', url: '/api/**/config/fingerbank_setting/collector', expect: (req, fixture) => expectByType('collector', req, fixture) },
        { method: '+(PATCH|PUT)', url: '/api/**/config/fingerbank_setting/proxy', expect: (req, fixture) => expectByType('proxy', req, fixture) },
        { method: '+(PATCH|PUT)', url: '/api/**/config/fingerbank_setting/query', expect: (req, fixture) => expectByType('query', req, fixture) },
        { method: '+(PATCH|PUT)', url: '/api/**/config/fingerbank_setting/upstream', expect: (req, fixture) => expectByType('upstream', req, fixture) },
      ]
    },
    {
      description: 'Device Change Detection - Passthrough Form',
      url: '/configuration/fingerbank/device_change_detection',
      interceptors: [
        { method: 'GET', url: '/api/**/config/base/fingerbank_device_change', fixture: res => res.body.item },

        { method: '+(PATCH|PUT)', url: '/api/**/config/base/fingerbank_device_change', expect: (req, fixture) => {
          Object.keys(fixture).forEach(key => {
            expect(req.body).to.have.property(key)
            expect(req.body[key]).to.deep.equal(fixture[key], key)
          })
        } },
      ]
    },
  ]
};