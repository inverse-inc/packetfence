module.exports = {
  root: true,
  env: {
    node: true
  },
  'extends': [
    'plugin:vue/essential',
    'eslint:recommended'
  ],
  rules: {
    'no-console': process.env.VUE_APP_DEBUG === 'true' ? 'off' : 'error',
    'no-debugger': process.env.VUE_APP_DEBUG === 'true' ? 'off' : 'error',
    'no-unused-vars': ['warn', {'args': 'after-used', 'ignoreRestSiblings': true}],
    'vue/multi-word-component-names': 'off'
  },
  parserOptions: {
    parser: '@babel/eslint-parser'
  }
}
