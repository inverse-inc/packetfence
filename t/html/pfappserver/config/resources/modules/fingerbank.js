const { splitKeys } = require('utils')

const expectByType = (type, req, fixture) => {
  const fixtureByType = splitKeys(fixture)
  if (type in fixtureByType) {
    Object.keys(fixtureByType[type]).forEach(key => {
      expect(req.body).to.have.property(key)
      expect(req.body[key]).to.equal(fixtureByType[type][key])
    })
  }
}

module.exports = {
  id: 'configuration-fingerbank-general-settings',
  description: 'Configuration - Fingerbank',
  tests: [
    {
      description: 'General Settings - Update Form',
      url: '/configuration/fingerbank/general_settings',
      form: {
        fixture: 'configuration-fingerbank-general-settings.json',
      },
      interceptors: [
        { method: '+(PATCH|PUT)', url: '/api/**/config/fingerbank_setting/collector', timeout: 1234, expect: (req, fixture) => expectByType('collector', req, fixture) },
        { method: '+(PATCH|PUT)', url: '/api/**/config/fingerbank_setting/proxy', expect: (req, fixture) => expectByType('proxy', req, fixture) },
        { method: '+(PATCH|PUT)', url: '/api/**/config/fingerbank_setting/query', expect: (req, fixture) => expectByType('query', req, fixture) },
        { method: '+(PATCH|PUT)', url: '/api/**/config/fingerbank_setting/upstream', expect: (req, fixture) => expectByType('upstream', req, fixture) },
      ]
    },
    {
      description: 'Device Change Detection - Update Form',
      url: '/configuration/fingerbank/device_change_detection',
      form: {
        fixture: 'configuration-fingerbank-device-change-detection.json',
      },
      interceptors: [
        { method: '+(PATCH|PUT)', url: '/api/**/config/base/fingerbank_device_change', expect: (req, fixture) => {
          Object.keys(fixture).forEach(key => {
            expect(req.body).to.have.property(key)
            expect(req.body[key]).to.equal(fixture[key])
          })
        } },
      ]
    },
  ]
};