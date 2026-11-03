const fs = require('fs')
const path = require('path')
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer')
const { discoverExtensions, writeRegistry } = require('./build/ui-extensions')

// UI extensions (see extensions/README.md). Without any extension nothing is
// written and the webpack configuration below is unchanged.
const extensionsOutDir = path.join(__dirname, '.pf-ui-extensions')
const extensions = discoverExtensions({ root: __dirname })
let extensionsRegistry = null
if (extensions.length > 0) {
  extensionsRegistry = writeRegistry(extensionsOutDir, extensions)
  process.stderr.write(`[pf-ui-extensions] building with: ${extensions.map(({ id, realDir }) => `${id} (${realDir})`).join(', ')}\n`)
} else if (fs.existsSync(extensionsOutDir)) {
  fs.rmSync(extensionsOutDir, { recursive: true, force: true }) // stale, from a previous build
}

module.exports = {
  publicPath: '/admin',
  outputDir: 'dist',
  indexPath: 'index.html',
  // source maps only for the debug builds, they embed the original sources
  // (of the UI extensions too)
  productionSourceMap: process.env.VUE_APP_DEBUG === 'true',
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
      ...((extensions.some(({ outsideRoot }) => outsideRoot))
        // postcss-loader looks for its configuration from each file's directory,
        // point extensions located outside of this directory to package.json
        ? { postcss: { postcssOptions: { config: __dirname } } }
        : {}
      ),
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
    if (extensionsRegistry) {
      // the registry alias must come before '@', the first matching alias wins
      const src = config.resolve.alias.get('@')
      config.resolve.alias.delete('@')
      config.resolve.alias.set('@/extensions/registry$', extensionsRegistry)
      config.resolve.alias.set('@', src)
      for (const { id, realDir } of extensions)
        config.resolve.alias.set(`@pf-ext/${id}`, realDir)
    }
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
