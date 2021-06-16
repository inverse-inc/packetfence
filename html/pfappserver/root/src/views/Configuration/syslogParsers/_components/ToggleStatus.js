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
          return store.dispatch('$_syslog_parsers/disableSyslogParser', item.value)
            .then(() => {
              store.dispatch('notification/info', { message: i18n.t('Syslog Parser <code>{id}</code> disabled.', item.value) })
              context.emit('input', 'disabled')
            })
            .catch(err => {
              const { response: { data: { message: errMsg } = {} } = {} } = err
              let message = i18n.t('Syslog Parser <code>{id}</code> was not disabled.', item.value)
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
          return store.dispatch('$_syslog_parsers/enableSyslogParser', item.value)
            .then(() => {
              store.dispatch('notification/info', { message: i18n.t('Syslog Parser <code>{id}</code> enabled.', item.value) })
              context.emit('input', 'enabled')
            })
            .catch(err => {
              const { response: { data: { message: errMsg } = {} } = {} } = err
              let message = i18n.t('Syslog Parser <code>{id}</code> was not enabled.', item.value)
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
  },
  searchableStoreName: {
    type: String
  }
}

export default {
  name: 'base-toggle-status',
  extends: BaseInputToggle,
  props
}
