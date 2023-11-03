const access_durations = require('./modules/access_durations')
const active_active = require('./modules/active_active')
const admin_login = require('./modules/admin_login')
const advanced = require('./modules/advanced')
const alerting = require('./modules/alerting')
const captive_portal = require('./modules/captive_portal')
const database_advanced = require('./modules/database_advanced')
const database_general = require('./modules/database_general')
const database_proxysql = require('./modules/database_proxysql')
const dns_configuration = require('./modules/dns_configuration')
const fingerbank = require('./modules/fingerbank')
const general = require('./modules/general')
const monit = require('./modules/monit')
const networks_fencing = require('./modules/networks_fencing')
const networks_inline = require('./modules/networks_inline')
const networks_network = require('./modules/networks_network')
const networks_parking = require('./modules/networks_parking')
const services = require('./modules/services')
const snmp_traps = require('./modules/snmp_traps')
const webservices = require('./modules/webservices')

module.exports = {
  access_durations,
  active_active,
  admin_login,
  advanced,
  alerting,
  captive_portal,
  database_advanced,
  database_general,
  database_proxysql,
  dns_configuration,
  fingerbank,
  general,
  monit,
  networks_fencing,
  networks_inline,
  networks_network,
  networks_parking,
  services,
  snmp_traps,
  webservices
}