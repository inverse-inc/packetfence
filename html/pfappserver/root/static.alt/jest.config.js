// process.env.VUE_CLI_BABEL_TARGET_NODE = true
// process.env.VUE_CLI_BABEL_TRANSPILE_MODULES = true

module.exports = {
  verbose: true,
  preset: "@vue/cli-plugin-unit-jest",
  testMatch: [
    "<rootDir>/**/*.spec.[jt]s?(x)",
    "<rootDir>/**/__tests__/*.[jt]s?(x)",
  ],
  transformIgnorePatterns: [
    "<rootDir>/node_modules/",
  ]
}
