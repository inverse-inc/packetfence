/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import i18n from '@/utils/locale'

export const pfAuthenticationConditionType = {
  NONE:                    'none',
  CONNECTION:              'connection',
  LDAPATTRIBUTE:           'ldapattribute',
  SUBSTRING:               'substring',
  TIME:                    'time',
  TIME_PERIOD:             'time_period'
}

export const pfAuthenticationConditionValue = {
  TEXT:                    'text',
  TIME:                    'time',
  TIME_PERIOD:             'time_period'
}

/**
 * Operator types for authentication types
 */
export const pfAuthenticationConditionOperators = {}

pfAuthenticationConditionOperators[pfAuthenticationConditionType.CONNECTION] = {
  'is':                    pfAuthenticationConditionValue.TEXT,
  'is not':                pfAuthenticationConditionValue.TEXT
}

pfAuthenticationConditionOperators[pfAuthenticationConditionType.LDAPATTRIBUTE] = {
  'starts':                pfAuthenticationConditionValue.TEXT,
  'equals':                pfAuthenticationConditionValue.TEXT,
  'not_equals':            pfAuthenticationConditionValue.TEXT,
  'contains':              pfAuthenticationConditionValue.TEXT,
  'ends':                  pfAuthenticationConditionValue.TEXT,
  'matches regexp':        pfAuthenticationConditionValue.TEXT,
  'is member of':          pfAuthenticationConditionValue.TEXT
}

pfAuthenticationConditionOperators[pfAuthenticationConditionType.SUBSTRING] = {
  'starts':                pfAuthenticationConditionValue.TEXT,
  'equals':                pfAuthenticationConditionValue.TEXT,
  'contains':              pfAuthenticationConditionValue.TEXT,
  'ends':                  pfAuthenticationConditionValue.TEXT,
  'matches regexp':        pfAuthenticationConditionValue.TEXT
}

pfAuthenticationConditionOperators[pfAuthenticationConditionType.TIME] = {
  'is before':             pfAuthenticationConditionValue.TIME,
  'is after':              pfAuthenticationConditionValue.TIME
}

pfAuthenticationConditionOperators[pfAuthenticationConditionType.TIME_PERIOD] = {
  'in_time_period':        pfAuthenticationConditionValue.TIME_PERIOD
}

/**
 * Values of some condition types
 */
export const pfAuthenticationConditionValues = {}

pfAuthenticationConditionValues[pfAuthenticationConditionType.CONNECTION] = (store) => {
  return [
    {
      group: i18n.t('Types'),
      items: [
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
      ]
    },
    {
      group: i18n.t('Groups'),
      items: [
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
  ]
}

/**
 * Helper that concatenates all operators for the specified types.
 *
 * @param {string[]} types - the types
 * @return {string[]} all operators
 */
export const pfAuthenticationConditionOperatorsForTypes = (types) => {
  let operators = []
  for (const type of types) {
    operators = operators.concat(Object.keys(pfAuthenticationConditionOperators[type]))
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
export const pfAuthenticationConditionValuesForOperator = (types, operator, store) => {
  let values = []
  let found = false
  for (const type of types) {
    let operators = pfAuthenticationConditionOperators[type]
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
