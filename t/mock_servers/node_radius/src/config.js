module.exports = {
  API_HOST : process.env.API_HOST || 'localhost',
  API_PORT : process.env.API_PORT || 8080,
  RADIUS_HOST : process.env.RADIUS_HOST || 'localhost',
  RADIUS_PORT: process.env.RADIUS_PORT || 1812,
  RADIUS_SECRET: process.env.RADIUS_SECRET || 'secret',
  RADIUS_USER_NAME: process.env.RADIUS_USER_NAME || null,
  RADIUS_USER_PASSWORD: process.env.RADIUS_USER_PASSWORD || null,
}