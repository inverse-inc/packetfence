module.exports = {
  baseUrl: '/static/alt',
  outputDir: 'dist',
  indexPath: '../../admin/v-index.tt',
  pluginOptions: {
    i18n: {
      locale: 'en',
      fallbackLocale: 'en',
      localeDir: 'locales',
      enableInSFC: false
    }
  },
  chainWebpack: config => {
    config.module
      .rule('vue')
      .use('vue-loader')
      .loader('vue-loader')
      .tap(options => {
        // Because we like to have automatic spaces between buttons
        options.compilerOptions.preserveWhitespace = true
        return options
      })
  }
}
