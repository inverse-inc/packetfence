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
        value: 'N', label: i18n.t('Disabled'),
        color: 'var(--danger)', icon: 'times',
        promise: (value, props) => {
          const { item } = toRefs(props)
          return store.dispatch('$_security_events/disableSecurityEvent', { quiet: true, ...item.value })
            .then(() => {
              store.dispatch('notification/info', { message: i18n.t('Security event <strong>{desc}</strong> disabled.', item.value) })
            })
            .catch(err => {
              const { response: { data: { message: errMsg } = {} } = {} } = err
              let message = i18n.t('Security event <strong>{desc}</strong> was not disabled', item.value)
              if (errMsg) message += ` (${errMsg})`
              store.dispatch('notification/danger', { message })
            })
        }
      },
      {
        value: 'Y', label: i18n.t('Enabled'),
        color: 'var(--success)', icon: 'check',
        promise: (value, props) => {
          const { item } = toRefs(props)
          return store.dispatch('$_security_events/enableSecurityEvent', { quiet: true, ...item.value })
            .then(() => {
              store.dispatch('notification/info', { message: i18n.t('Security event <strong>{desc}</strong> enabled.', item.value) })
            })
            .catch(err => {
              const { response: { data: { message: errMsg } = {} } = {} } = err
              let message = i18n.t('Security event <strong>{desc}</strong> was not enabled', item.value)
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
