module.exports = {
  baseUrl: '/static/alt',
  outputDir: 'dist',
  indexPath: '../../admin/v-index.tt',
  css: {
    sourceMap: process.env.VUE_APP_DEBUG
  },
  pluginOptions: {
    i18n: {
      locale: 'en',
      fallbackLocale: 'en',
      localeDir: 'locales',
      enableInSFC: false
    }
  },
  chainWebpack: config => {
    if (process.env.VUE_APP_DEBUG) {
      config.optimization.minimize(false)
      config.optimization.delete('minimizer')
    }
  }
}
