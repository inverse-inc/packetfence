export const pfSearchConditionType = {
  BOOL: 'bool', // is true or is false
  LIST: 'list', // is only
  LISTEXTEND: 'list', // is or is not
  SUBSTRING: 'substring'
}

export const pfConditionOperators = {}
pfConditionOperators[pfSearchConditionType.SUBSTRING] = ['start', 'equals', 'contains', 'ends', 'matches']
pfConditionOperators[pfSearchConditionType.BOOL] = ['true', 'false']

export const pfSearchConditionFormatter = {
  MAC: 'mac'
}
