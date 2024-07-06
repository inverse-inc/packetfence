const adminRoles = require('./modules/adminRoles')
const billingTiers = require('./modules/billingTiers')
const clouds = require('./modules/clouds')
const connectionProfiles = require('./modules/connectionProfiles')
const connectors = require('./modules/connectors')
const domains = require('./modules/domains')
const eventLoggers = require('./modules/eventLoggers')
const filterEngines = require('./modules/filterEngines')
const fingerbankCombinations = require('./modules/fingerbankCombinations')
const fingerbankDevices = require('./modules/fingerbankDevices')
const fingerbankDhcpFingerprints = require('./modules/fingerbankDhcpFingerprints')
const fingerbankDhcpv6Enterprises = require('./modules/fingerbankDhcpv6Enterprises')
const fingerbankDhcpv6Fingerprints = require('./modules/fingerbankDhcpv6Fingerprints')
const fingerbankDhcpVendors = require('./modules/fingerbankDhcpVendors')
const fingerbankMacVendors = require('./modules/fingerbankMacVendors')
const fingerbankUserAgents = require('./modules/fingerbankUserAgents')
const firewalls = require('./modules/firewalls')
const floatingDevices = require('./modules/floatingDevices')
const maintenaceTasks = require('./modules/maintenanceTasks')
const mfas = require('./modules/mfas')
const networkBehaviorPolicies = require('./modules/networkBehaviorPolicies')
const pkiCas = require('./modules/pkiCas')
const pkiProviders = require('./modules/pkiProviders')
const provisionings = require('./modules/provisionings')
const radiusProfiles = require('./modules/radiusProfiles')
const radiusSslCertificates = require('./modules/radiusSslCertificates')
const realms = require('./modules/realms')
const roles = require('./modules/roles')
const scanEngines = require('./modules/scanEngines')
const securityEvents = require('./modules/securityEvents')
const selfServices = require('./modules/selfServices')
const sources = require('./modules/sources')
const switches = require('./modules/switches')
const switchGroups = require('./modules/switchGroups')
const switchTemplates = require('./modules/switchTemplates')
const syslogForwarders = require('./modules/syslogForwarders')
const syslogParsers = require('./modules/syslogParsers')
const wrixLocations = require('./modules/wrixLocations')

module.exports = {
  adminRoles,
  billingTiers,
  clouds,
  connectionProfiles,
  connectors,
  domains,
  eventLoggers,
//  filterEngines, // issue(s)
  fingerbankCombinations,
  fingerbankDevices,
  fingerbankDhcpFingerprints,
  fingerbankDhcpv6Enterprises,
  fingerbankDhcpv6Fingerprints,
  fingerbankDhcpVendors,
  fingerbankMacVendors,
  fingerbankUserAgents,
  firewalls,
  floatingDevices,
  networkBehaviorPolicies,
  maintenaceTasks,
  mfas,
//  pkiCas, // incomplete
  pkiProviders,
  provisionings,
  radiusProfiles,
  radiusSslCertificates,
  realms,
  roles,
  scanEngines,
  securityEvents,
  selfServices,
  sources,
  switches,
  switchGroups,
  switchTemplates,
  syslogForwarders,
  syslogParsers,
  wrixLocations
}