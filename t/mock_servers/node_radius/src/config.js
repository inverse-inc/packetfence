module.exports = {
  API_HOST : process.env.npm_config_api_host || 'localhost',
  API_PORT : process.env.npm_config_api_port || 8080,
  RADIUS_HOST : process.env.npm_config_radius_host || 'localhost',
  RADIUS_PORT: process.env.npm_config_radius_port || 1812,
  RADIUS_SECRET: process.env.npm_config_radius_secret || 'secret',
  RADIUS_USER_NAME: process.env.npm_config_radius_user_name || null,
  RADIUS_USER_PASSWORD: process.env.npm_config_radius_user_password || null,
}