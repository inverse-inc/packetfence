/* eslint key-spacing: ["error", { "mode": "minimum" }] */

export const pfSearchConditionType = {
  BOOL:                    'bool', // is true or is false
  LIST:                    'list', // is only
  LISTEXTEND:              'list', // is or is not
  SUBSTRING:               'substring',
  NODE_STATUS:             'node_status',
  ROLE:                    'role',
  CONNECTION_TYPE:         'connection_type',
  ONLINE:                  'online'
}

export const pfSearchConditionValue = {
  TEXT:                    'text',
  SELECT:                  'select'
}

/**
 * Operator types for condition types
 */
// See lib/pf/UnifiedApi/Search.pm#L20
export const pfConditionOperators = {}
pfConditionOperators[pfSearchConditionType.SUBSTRING] = {
  'equals':                pfSearchConditionValue.TEXT,
  'not_equals':            pfSearchConditionValue.TEXT,
  'starts_with':           pfSearchConditionValue.TEXT,
  'ends_with':             pfSearchConditionValue.TEXT,
  'contains':              pfSearchConditionValue.TEXT
}
pfConditionOperators[pfSearchConditionType.BOOL] = {
  'is_true':               null,
  'is_false':              null
}
pfConditionOperators[pfSearchConditionType.NODE_STATUS] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.ROLE] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.CONNECTION_TYPE] = {
  'equals':                    pfSearchConditionValue.SELECT,
  'not_equals':                pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.ONLINE] = {
  'equals':                    pfSearchConditionValue.SELECT,
  'not_equals':                pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.VOIP] = {
  'equals':                    pfSearchConditionValue.SELECT,
  'not_equals':                pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.VIOLATION] = {
  'equals':                    pfSearchConditionValue.SELECT,
  'not_equals':                pfSearchConditionValue.SELECT
}

/**
 * Values of some condition types
 */
export const pfSearchConditionValues = {}
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
pfSearchConditionValues[pfSearchConditionType.ROLE] = (store) => {
  return store.getters['config/rolesList']
}
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
pfSearchConditionValues[pfSearchConditionType.VOIP] = [
  {
    value: 'yes',
    text: 'Yes'
  },
  {
    value: 'no',
    text: 'No'
  }
]
pfSearchConditionValues[pfSearchConditionType.VIOLATION] = (store) => {
  return store.getters['config/violationsList']
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
