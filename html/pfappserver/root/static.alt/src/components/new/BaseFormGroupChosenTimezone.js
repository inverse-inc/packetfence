import BaseFormGroupChosenOne, { props as BaseFormGroupChosenOneProps } from './BaseFormGroupChosenOne'
import timezones from '@/globals/timezones'

export const props = {
  ...BaseFormGroupChosenOneProps,

  options: {
    type: Array,
    default: () => Object.keys(timezones).map(continent => ({
      group: continent,
      items: Object.keys(timezones[continent]).map(timezone => ({ text: timezones[continent][timezone], value: `${continent}/${timezone}` }))
    }))
  },
  groupLabel: {
    type: String,
    default: 'group'
  },
  groupValues: {
    type: String,
    default: 'items'
  }
}

export default {
  name: 'base-form-group-chosen-timezone',
  extends: BaseFormGroupChosenOne,
  props
}
