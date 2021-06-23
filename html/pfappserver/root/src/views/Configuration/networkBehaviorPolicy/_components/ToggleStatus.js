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
        value: 'disabled', label: i18n.t('Disabled'),
        color: 'var(--danger)', icon: 'times',
        promise: (value, props, context) => {
          const { item } = toRefs(props)
          return store.dispatch('$_network_behavior_policies/disableNetworkBehaviorPolicy', { quiet: true, ...item.value })
            .then(() => {
              context.emit('input', 'disabled')
              store.dispatch('notification/info', { message: i18n.t('Network behavior policy <code>{id}</code> disabled.', item.value) })
            })
            .catch(err => {
              const { response: { data: { message: errMsg } = {} } = {} } = err
              let message = i18n.t('Network behavior policy <code>{id}</code> could not be disabled.', item.value)
              if (errMsg) message += ` (${errMsg})`
              store.dispatch('notification/danger', { message })
            })
        }
      },
      {
        value: 'enabled', label: i18n.t('Enabled'),
        color: 'var(--success)', icon: 'check',
        promise: (value, props, context) => {
          const { item } = toRefs(props)
          return store.dispatch('$_network_behavior_policies/enableNetworkBehaviorPolicy', { quiet: true, ...item.value })
            .then(() => {
              context.emit('input', 'enabled')
              store.dispatch('notification/info', { message: i18n.t('Network behavior policy <code>{id}</code> enabled.', item.value) })
            })
            .catch(err => {
              const { response: { data: { message: errMsg } = {} } = {} } = err
              let message = i18n.t('Network behavior policy <code>{id}</code> could not be enabled.', item.value)
              if (errMsg) message += ` (${errMsg})`
              store.dispatch('notification/danger', { message })
            })
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
