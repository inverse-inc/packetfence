import { BaseFormGroupChosenMultipleSearchable, BaseFormGroupChosenMultipleSearchableProps } from '@/components/new/'

export const props = {
  ...BaseFormGroupChosenMultipleSearchableProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      { text: 'Windows Phone OS', value: '33507' },
      { text: 'Mac OS X or macOS', value: '2' },
      { text: 'Android OS', value: '33453' },
      { text: 'Windows OS', value: '1' },
      { text: 'BlackBerry OS', value: '33471' },
      { text: 'iOS', value: '33450' },
      { text: 'Linux OS', value: '5' }
    ])
  }
}

export default {
  name: 'base-form-group-oses',
  extends: BaseFormGroupChosenMultipleSearchable,
  props
}
