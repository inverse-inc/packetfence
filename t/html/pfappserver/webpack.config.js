const path = require('path');

module.exports = {
  mode: 'none',
  module: {
    rules: [
      {
        test: /\.jsx?$/,
        exclude: [/node_modules/],
        use: [{
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-env'],
          },
        }],
      },
    ],
  },
  resolve: {
    modules: [
      path.resolve(__dirname, './'),
      path.resolve(__dirname, './cypress'),
    ],
  },
};