const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer')

module.exports = {
  publicPath: '/admin',
  outputDir: 'dist',
  indexPath: 'index.html',
  devServer: {
    port: 8081,
    server: 'https',
    proxy: {
      '^/static/doc': {
        target: `https://${process.env.VUE_APP_API_SOCKET_ADDRESS}`,
        secure: false,
        changeOrigin: true
      },
      '^/api': {
        target: `https://${process.env.VUE_APP_API_SOCKET_ADDRESS}`,
        secure: false,
        changeOrigin: true
      },
      '^/netdata': {
        target: `https://${process.env.VUE_APP_API_SOCKET_ADDRESS}`,
        secure: false,
        changeOrigin: true
      }
    }
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
    config.optimization.splitChunks({
      chunks: 'all',
      maxInitialRequests: 10,
      maxAsyncRequests: 15,
      cacheGroups: {
        plotly: {
          test: /[\\/]node_modules[\\/](plotly\.js|plotly\.js-locales)[\\/]/,
          name: 'vendor-plotly',
          chunks: 'all',
          priority: 30,
          enforce: true
        },
        bootstrapVue: {
          test: /[\\/]node_modules[\\/]bootstrap-vue[\\/]/,
          name: 'vendor-bootstrap-vue',
          chunks: 'all',
          priority: 20
        },
        aceEditor: {
          test: /[\\/]node_modules[\\/](ace-builds|vue2-ace-editor|brace)[\\/]/,
          name: 'vendor-ace',
          chunks: 'async',
          priority: 20
        },
        defaultVendors: {
          test: /[\\/]node_modules[\\/]/,
          name: 'chunk-vendors',
          chunks: 'initial',
          priority: -10,
          reuseExistingChunk: true
        },
        common: {
          minChunks: 2,
          priority: -20,
          chunks: 'async',
          name: 'common',
          reuseExistingChunk: true
        }
      }
    })
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
          },
          {
            test: /\.js$/,
            include: /node_modules[\\/]plotly\.js/,
            use: ['ify-loader']
          }
        ]
      }
    }
  }
}
