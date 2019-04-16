/* eslint key-spacing: ["error", { "mode": "minimum" }] */

export const pfSearchConditionType = {
  /**
   * Simple fields
   */
  BOOL:                    'bool', // is true or is false
  DATETIME:                'datetime',
  INTEGER:                 'integer',
  LIST:                    'list', // is only
  LISTEXTEND:              'list', // is or is not
  PREFIXMULTIPLE:          'prefixmultiple',
  SUBSTRING:               'substring',

  /**
   * Static fields
   */
  CONNECTION_TYPE:         'connection_type',
  NODE_STATUS:             'node_status',
  ONLINE:                  'online',
  YESNO:                   'yesno',
  NAS_PORT_TYPE:           'nas_port_type',

  /**
   * Promise fields
   */
  CONNECTION_PROFILE:      'profile',
  DOMAIN:                  'domain',
  REALM:                   'realm',
  ROLE:                    'role',
  SOURCE:                  'source',
  SWITCH_GROUP:            'switch_group'
}

export const pfSearchConditionValue = {
  TEXT:                    'text',
  SELECT:                  'select',
  DATETIME:                'datetime',
  PREFIXMULTIPLE:          'prefixmultiple'
}

/**
 * Operator types for condition types
 */
// See lib/pf/UnifiedApi/Search.pm#L20
export const pfConditionOperators = {}

/**
 * Simple fields
 */
pfConditionOperators[pfSearchConditionType.BOOL] = {
  'is_true':               null,
  'is_false':              null
}
pfConditionOperators[pfSearchConditionType.DATETIME] = {
  'greater_than':          pfSearchConditionValue.DATETIME,
  'greater_than_equals':   pfSearchConditionValue.DATETIME,
  'less_than':             pfSearchConditionValue.DATETIME,
  'less_than_equals':      pfSearchConditionValue.DATETIME
}
pfConditionOperators[pfSearchConditionType.INTEGER] = {
  'equals':                pfSearchConditionValue.TEXT,
  'not_equals':            pfSearchConditionValue.TEXT,
  'greater_than':          pfSearchConditionValue.TEXT,
  'less_than':             pfSearchConditionValue.TEXT,
  'greater_than_equals':   pfSearchConditionValue.TEXT,
  'less_than_equals':      pfSearchConditionValue.TEXT
}
pfConditionOperators[pfSearchConditionType.PREFIXMULTIPLE] = {
  'equals':                pfSearchConditionValue.PREFIXMULTIPLE,
  'not_equals':            pfSearchConditionValue.PREFIXMULTIPLE,
  'greater_than':          pfSearchConditionValue.PREFIXMULTIPLE,
  'less_than':             pfSearchConditionValue.PREFIXMULTIPLE,
  'greater_than_equals':   pfSearchConditionValue.PREFIXMULTIPLE,
  'less_than_equals':      pfSearchConditionValue.PREFIXMULTIPLE
}
pfConditionOperators[pfSearchConditionType.SUBSTRING] = {
  'equals':                pfSearchConditionValue.TEXT,
  'not_equals':            pfSearchConditionValue.TEXT,
  'starts_with':           pfSearchConditionValue.TEXT,
  'ends_with':             pfSearchConditionValue.TEXT,
  'contains':              pfSearchConditionValue.TEXT
}

/**
 * Static fields
 */
pfConditionOperators[pfSearchConditionType.CONNECTION_TYPE] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.NODE_STATUS] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.ONLINE] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.YESNO] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.NAS_PORT_TYPE] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}

/**
 * Promise fields
 */
pfConditionOperators[pfSearchConditionType.CONNECTION_PROFILE] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.DOMAIN] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.REALM] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.ROLE] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.SOURCE] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.SWITCH_GROUP] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}

/**
 * Values of some condition types
 */
export const pfSearchConditionValues = {}
// See lib/pf/config.pm#L344-L350
pfSearchConditionValues[pfSearchConditionType.CONNECTION_TYPE] = [
  {
    value: 'Wireless-802.11-EAP',
    text: 'WiFi 802.1X'
  },
  {
    value: 'Wireless-802.11-NoEAP',
    text: 'WiFi MAC Auth'
  },
  {
    value: 'Ethernet-EAP',
    text: 'Wired 802.1x'
  },
  {
    value: 'WIRED_MAC_AUTH',
    text: 'Wired MAC Auth'
  },
  {
    value: 'SNMP-Traps',
    text: 'Wired SNMP'
  },
  {
    value: 'Inline',
    text: 'Inline'
  }
]
pfSearchConditionValues[pfSearchConditionType.NODE_STATUS] = [
  {
    value: 'reg',
    text: 'Registered'
  },
  {
    value: 'unreg',
    text: 'Unregistered'
  },
  {
    value: 'pending',
    text: 'Pending'
  }
]
pfSearchConditionValues[pfSearchConditionType.ONLINE] = [
  {
    value: 'on',
    text: 'Online'
  },
  {
    value: 'off',
    text: 'Offline'
  },
  {
    value: 'unknown',
    text: 'Unknown'
  }
]
pfSearchConditionValues[pfSearchConditionType.YESNO] = [
  {
    value: 'yes',
    text: 'Yes'
  },
  {
    value: 'no',
    text: 'No'
  }
]
pfSearchConditionValues[pfSearchConditionType.NAS_PORT_TYPE] = [
  { text: 'Async', value: 'Async' },
  { text: 'Sync', value: 'Sync' },
  { text: 'ISDN', value: 'ISDN' },
  { text: 'ISDN-V120', value: 'ISDN-V120' },
  { text: 'ISDN-V110', value: 'ISDN-V110' },
  { text: 'Virtual', value: 'Virtual' },
  { text: 'PIAFS', value: 'PIAFS' },
  { text: 'HDLC-Clear-Channel', value: 'HDLC-Clear-Channel' },
  { text: 'X.25', value: 'X.25' },
  { text: 'X.75', value: 'X.75' },
  { text: 'G.3-Fax', value: 'G.3-Fax' },
  { text: 'SDSL', value: 'SDSL' },
  { text: 'ADSL-CAP', value: 'ADSL-CAP' },
  { text: 'ADSL-DMT', value: 'ADSL-DMT' },
  { text: 'IDSL', value: 'IDSL' },
  { text: 'Ethernet', value: 'Ethernet' },
  { text: 'xDSL', value: 'xDSL' },
  { text: 'Cable', value: 'Cable' },
  { text: 'Wireless-Other', value: 'Wireless-Other' },
  { text: 'Wireless-802.11', value: 'Wireless-802.11' },
  { text: 'Token-Ring', value: 'Token-Ring' },
  { text: 'FDDI', value: 'FDDI' },
  { text: 'Wireless-CDMA2000', value: 'Wireless-CDMA2000' },
  { text: 'Wireless-UMTS', value: 'Wireless-UMTS' },
  { text: 'Wireless-1X-EV', value: 'Wireless-1X-EV' },
  { text: 'IAPP', value: 'IAPP' },
  { text: 'FTTP', value: 'FTTP' },
  { text: 'Wireless-802.16', value: 'Wireless-802.16' },
  { text: 'Wireless-802.20', value: 'Wireless-802.20' },
  { text: 'Wireless-802.22', value: 'Wireless-802.22' },
  { text: 'xPON', value: 'xPON' },
  { text: 'Wireless-XGP', value: 'Wireless-XGP' },
  { text: 'PPPoA', value: 'PPPoA' },
  { text: 'PPPoEoA', value: 'PPPoEoA' },
  { text: 'PPPoEoE', value: 'PPPoEoE' },
  { text: 'PPPoEoVLAN', value: 'PPPoEoVLAN' },
  { text: 'PPPoEoQinQ ', value: 'PPPoEoQinQ ' }
]

pfSearchConditionValues[pfSearchConditionType.CONNECTION_PROFILE] = (store) => {
  store.dispatch('config/getConnectionProfiles')
  return store.getters['config/connectionProfilesList']
}
pfSearchConditionValues[pfSearchConditionType.DOMAIN] = (store) => {
  store.dispatch('config/getDomains')
  return store.getters['config/domainsList']
}
pfSearchConditionValues[pfSearchConditionType.REALM] = (store) => {
  store.dispatch('config/getRealms')
  return store.getters['config/realmsList']
}
pfSearchConditionValues[pfSearchConditionType.ROLE] = (store) => {
  store.dispatch('config/getRoles')
  return store.getters['config/rolesList']
}
pfSearchConditionValues[pfSearchConditionType.SOURCE] = (store) => {
  store.dispatch('config/getSources')
  return store.getters['config/sourcesList']
}
pfSearchConditionValues[pfSearchConditionType.SWITCH_GROUP] = (store) => {
  store.dispatch('config/getSwitchGroups')
  return store.getters['config/switchGroupsList']
}

export const pfSearchConditionFormatter = {
  MAC: 'mac'
}

/**
 * Helper that concatenates all operators for the specified types.
 *
 * @param {string[]} types - the types
 * @return {string[]} all operators
 */
export const pfSearchOperatorsForTypes = (types) => {
  let operators = []
  for (const type of types) {
    operators = operators.concat(Object.keys(pfConditionOperators[type]))
  }
  return [...(new Set(operators))]
}

/**
 * Helper to lookup values for the operator within the scope of the specified types.
 * First operator wins. Types order is therefore important.
 *
 * @param {string[]} types - the types
 * @param {string} operator - the operator
 * @return {Object[]} the values
 */
export const pfSearchValuesForOperator = (types, operator, store) => {
  let values = []
  let found = false
  for (const type of types) {
    let operators = pfConditionOperators[type]
    for (const op of Object.keys(operators)) {
      if (op === operator) {
        values = pfSearchConditionValues[type]
        found = true
        break
      }
    }
    if (found) {
      break
    }
  }
  if (values && typeof values === 'function') {
    return values(store)
  } else {
    return values
  }
}
