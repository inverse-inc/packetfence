/* eslint key-spacing: ["error", { "mode": "minimum" }] */

export const pfSearchConditionType = {
  BOOL:                    'bool', // is true or is false
  LIST:                    'list', // is only
  LISTEXTEND:              'list', // is or is not
  SUBSTRING:               'substring',
  ROLE:                    'role',
  CONNECTION_TYPE:         'connection_type'
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
pfConditionOperators[pfSearchConditionType.ROLE] = {
  'equals':                pfSearchConditionValue.SELECT,
  'not_equals':            pfSearchConditionValue.SELECT
}
pfConditionOperators[pfSearchConditionType.CONNECTION_TYPE] = {
  'equals':                    pfSearchConditionValue.SELECT,
  'not_equals':                pfSearchConditionValue.SELECT
}

/**
 * Values of some condition types
 */
export const pfSearchConditionValues = {}
pfSearchConditionValues[pfSearchConditionType.ROLE] = (store) => {
  return store.state.config.roles.map((item) => {
    // Remap for b-form-select component
    return { value: item.id, text: `${item.id} - ${item.notes}` }
  })
}
// See lib/pf/config.pm#L318
pfSearchConditionValues[pfSearchConditionType.CONNECTION_TYPE] = [
  {
    value: 'WIRELESS_802_1X',
    text: 'Wireless 802.1x'
  },
  {
    value: 'WIRELESS_MAC_AUTH',
    text: 'Wireless MAC Auth'
  }
]

export const pfSearchConditionFormatter = {
  MAC: 'mac'
}

/**
 * Helper that concatenates all operaorts for the specified types.
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
