module.exports = {
  'presets': [
    [
      '@vue/app',
      {
        'useBuiltIns': 'entry'
      }
    ]
  ],
  'plugins': [
    [
      '@babel/plugin-proposal-decorators',
      {
        'legacy': true
      }
    ],
    [
      '@babel/plugin-proposal-class-properties',
      {
        'loose' : true
      }
    ]
  ]
}
