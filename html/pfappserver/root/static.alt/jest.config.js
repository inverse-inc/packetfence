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
