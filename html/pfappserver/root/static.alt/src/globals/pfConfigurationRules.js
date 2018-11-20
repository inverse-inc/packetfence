/* eslint key-spacing: ["error", { "mode": "minimum" }] */

export const pfAuthenticationConditionType = {
  SUBSTRING:               'substring',
  SUBSTRING_MEMBER:        'substring_member',
  HOUR_MINUTE:             'hour_minute',
  TIMEPERIOD:              'timeperiod',
  CONNECTION_TYPE:         'connection_type'
}

export const pfAuthenticationConditionValue = {
  TEXT:                    'text',
  HOUR_MINUTE:             'hour_minute',
  TIMEPERIOD:              'timeperiod'
}

/**
 * Operator types for authentication types
 */
export const pfConditionOperators = {}

pfConditionOperators[pfAuthenticationConditionType.SUBSTRING] = {
  'starts':                pfAuthenticationConditionValue.TEXT,
  'equals':                pfAuthenticationConditionValue.TEXT,
  'contains':              pfAuthenticationConditionValue.TEXT,
  'ends':                  pfAuthenticationConditionValue.TEXT,
  'matches regexp':        pfAuthenticationConditionValue.TEXT
}

pfConditionOperators[pfAuthenticationConditionType.SUBSTRING_MEMBER] = {
  'starts':                pfAuthenticationConditionValue.TEXT,
  'equals':                pfAuthenticationConditionValue.TEXT,
  'not_equals':            pfAuthenticationConditionValue.TEXT,
  'contains':              pfAuthenticationConditionValue.TEXT,
  'ends':                  pfAuthenticationConditionValue.TEXT,
  'matches regexp':        pfAuthenticationConditionValue.TEXT,
  'is member of':          pfAuthenticationConditionValue.TEXT
}

pfConditionOperators[pfAuthenticationConditionType.HOUR_MINUTE] = {
  'is before':             pfAuthenticationConditionValue.HOUR_MINUTE,
  'is after':              pfAuthenticationConditionValue.HOUR_MINUTE
}

pfConditionOperators[pfAuthenticationConditionType.TIMEPERIOD] = {
  'in_time_period':        pfAuthenticationConditionValue.TIMEPERIOD
}

pfConditionOperators[pfAuthenticationConditionType.CONNECTION_TYPE] = {
  'is':                    pfAuthenticationConditionValue.TEXT,
  'is not':                pfAuthenticationConditionValue.TEXT
}

/**
 * Values of some condition types
 */
export const pfAuthenticationConditionValues = {}

pfAuthenticationConditionValues[pfAuthenticationConditionType.CONNECTION_TYPE] = {
  Types: [
    {
      value: 'Ethernet-EAP',
      text: 'Ethernet-EAP'
    },
    {
      value: 'Ethernet-NoEAP',
      text: 'Ethernet-NoEAP'
    },
    {
      value: 'Ethernet-Web-Auth',
      text: 'Ethernet-Web-Auth'
    },
    {
      value: 'Inline',
      text: 'Inline'
    },
    {
      value: 'SNMP-Traps',
      text: 'SNMP-Traps'
    },
    {
      value: 'Wireless-802.11-EAP',
      text: 'Wireless-802.11-EAP'
    },
    {
      value: 'Wireless-802.11-NoEAP',
      text: 'Wireless-802.11-NoEAP'
    },
    {
      value: 'Wireless-Web-Auth',
      text: 'Wireless-Web-Auth'
    }
  ],
  Groups: [
    {
      value: 'EAP',
      text: 'EAP'
    },
    {
      value: 'Ethernet',
      text: 'Ethernet'
    },
    {
      value: 'Web-Auth',
      text: 'Web-Auth'
    },
    {
      value: 'Wireless',
      text: 'Wireless'
    }
  ]
}

/**
 * Helper that concatenates all operators for the specified types.
 *
 * @param {string[]} types - the types
 * @return {string[]} all operators
 */
export const pfAuthenticationOperatorsForTypes = (types) => {
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
export const pfAuthenticationValuesForOperator = (types, operator, store) => {
  let values = []
  let found = false
  for (const type of types) {
    let operators = pfConditionOperators[type]
    for (const op of Object.keys(operators)) {
      if (op === operator) {
        values = pfAuthenticationConditionValues[type]
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

