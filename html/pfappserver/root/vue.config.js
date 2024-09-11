const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer')

module.exports = {
  publicPath: '/admin',
  outputDir: 'dist',
  indexPath: 'index.html',
  devServer: {
    port: 8081,
    server: 'https',
    proxy: `https://${process.env.VUE_APP_API_SOCKET_ADDRESS}`
  },
  css: {
    sourceMap: process.env.VUE_APP_DEBUG === 'true',
    extract: process.env.VUE_APP_DEBUG !== 'true',
    loaderOptions: {
      sass: {
        sassOptions: {
          includePaths: [
            'node_modules',
            'src/styles'
          ]
        },
        additionalData: [
          `@import "bootstrap/scss/functions";`,
          `@import "bootstrap/scss/mixins/border-radius";`,
          `@import "bootstrap/scss/mixins/box-shadow";`,
          `@import "bootstrap/scss/mixins/breakpoints";`,
          `@import "bootstrap/scss/mixins/transition";`,
          `@import "variables";`
        ].join('')
      }
    }
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
    if (process.env.VUE_APP_DEBUG === 'true') {
      config.optimization.minimize(false)
      config.optimization.delete('minimizer')
    }
  },
  configureWebpack: config => {
    if (process.env.VUE_APP_DEBUG === 'true') {
      config.plugins.push(new BundleAnalyzerPlugin({
        analyzerMode: 'static',
        openAnalyzer: false
      }))
    }
    config.resolve.fallback = { "path": require.resolve("path-browserify") }
    return {
      module: {
        rules: [
          {
            test: /\.mjs$/,
            include: /node_modules/,
            type: "javascript/auto"
          }
        ]
      }
    }
  }
}
