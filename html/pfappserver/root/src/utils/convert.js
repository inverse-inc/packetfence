import transform from 'lodash/transform'
import isPlainObject from 'lodash/isPlainObject'
import isInteger from 'lodash/isInteger'

const convert = {
  statusToVariant(params) {
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
  return {'text': value, 'value': value}
}

export function intsToStrings(obj) {
  return transform(obj, (result, value, key) => {
    if (isPlainObject(value)) {
      result[key] = intsToStrings(value);
    } else {
      result[key] = isInteger(value) ? value.toString() : value;
    }
  });
}
