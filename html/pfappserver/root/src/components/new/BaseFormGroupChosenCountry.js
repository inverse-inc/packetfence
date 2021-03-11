import BaseFormGroupChosenOne, { props as BaseFormGroupChosenOneProps } from './BaseFormGroupChosenOne'
import countries from '@/globals/countries'

export const props = {
  ...BaseFormGroupChosenOneProps,

  // overload :options default
  options: {
    type: Array,
    default: () => Object.keys(countries).map(countryCode => ({ value: countryCode, text: countries[countryCode] }))
  }
}

export default {
  name: 'base-form-group-chosen-country',
  extends: BaseFormGroupChosenOne,
  props
}
