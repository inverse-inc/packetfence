import _ from 'lodash'

const convert = {
  statusToVariant (params) {
    let variant = params.variant || ''
    switch (params.status) {
      case 'success':
        variant = 'success'
        break
      case 'skipped':
        variant = 'warning'
        break
      case 'failed':
        variant = 'danger'
        break
    }
    return variant
  }
}

export default convert

export function valueToSelectValue(value) {
  return {"text": value, "value": value}
}

export function intsToStrings(obj) {
  return _.transform(obj, (result, value, key) => {
    if (_.isPlainObject(value)) {
      result[key] = intsToStrings(value);
    } else {
      result[key] = _.isInteger(value) ? value.toString() : value;
    }
  });
}
