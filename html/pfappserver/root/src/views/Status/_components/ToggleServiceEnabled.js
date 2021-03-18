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
        value: false, label: i18n.t('Disabled'),
        color: 'var(--danger)', icon: 'times',
        promise: (value, props) => {
          const { name } = toRefs(props)
          return store.dispatch('$_status/disableService', name.value)
            .then(() => {
              store.dispatch('notification/info', { message: i18n.t('Service <code>{service}</code> disabled.', { service: name.value }) })
            })
        }
      },
      {
        value: true, label: i18n.t('Enabled'),
        color: 'var(--success)', icon: 'check',
        promise: (value, props) => {
          const { name } = toRefs(props)
          return store.dispatch('$_status/enableService', name.value)
            .then(() => {
              store.dispatch('notification/info', { message: i18n.t('Service <code>{service}</code> enabled.', { service: name.value }) })
            })
        }
      }
    ])
  },
  labelRight: {
    type: Boolean,
    default: true
  },
  name: {
    type: String
  }
}

export default {
  name: 'toggle-service-enabled',
  extends: BaseInputToggle,
  props
}
