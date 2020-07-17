module.exports = {
  root: true,
  env: {
    node: true
  },
  'extends': [
    'plugin:vue/vue3-essential',
    'eslint:recommended'
  ],
  rules: {
    'no-console': process.env.VUE_APP_DEBUG === 'true' ? 'off' : 'error',
    'no-debugger': process.env.VUE_APP_DEBUG === 'true' ? 'off' : 'error',
    'no-unused-vars': ['warn', {'args': 'after-used', 'ignoreRestSiblings': true}]
  },
  parserOptions: {
    parser: 'babel-eslint'
  }
}
