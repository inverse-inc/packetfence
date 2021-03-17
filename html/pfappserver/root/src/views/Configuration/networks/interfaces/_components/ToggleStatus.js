import { toRefs } from '@vue/composition-api'
import { BaseInputToggle, BaseInputToggleProps } from '@/components/new'
import i18n from '@/utils/locale'
import store from '@/store'

export const props = {
  ...BaseInputToggleProps,

  // overload :options default
  options: {
    type: Array,
    default: () => ([
      {
        value: false, label: i18n.t('Down'),
        color: 'var(--danger)', icon: 'times',
        promise: (value, props) => {
          const { item } = toRefs(props)
          const { id } = item.value
          return store.dispatch(`$_interfaces/downInterface`, id)
        }
      },
      {
        value: true, label: i18n.t('Up'),
        color: 'var(--success)', icon: 'check',
        promise: (value, props) => {
          const { item } = toRefs(props)
          const { id } = item.value
          return store.dispatch(`$_interfaces/upInterface`, id)
        }
      }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  },
  item: {
    type: Object
  }
}

export default {
  name: 'base-toggle-status',
  extends: BaseInputToggle,
  props
}
