const api = require('./api.js')
const radius = require('./radius.js')
const config = require('./config.js')

api.listen(config.API_PORT, config.API_HOST, () => console.info(`API listening on http://${config.API_HOST}:${config.API_PORT}`))

var mock = new radius(config.RADIUS_HOST, config.RADIUS_PORT, config.RADIUS_SECRET, config.RADIUS_USER_NAME, config.RADIUS_USER_PASSWORD)
mock.bind()
