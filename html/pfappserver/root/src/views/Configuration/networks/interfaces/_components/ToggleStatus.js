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
        promise: (value, props, context) => {
          const { item } = toRefs(props)
          const { id } = item.value
          return store.dispatch(`$_interfaces/downInterface`, id)
            .then(() => {
              context.emit('input', 'down')
              store.dispatch('notification/info', { message: i18n.t('Interface <code>{id}</code> down.', item.value) })
            })
            .catch(err => {
              const { response: { data: { message: errMsg } = {} } = {} } = err
              let message = i18n.t('Interface <code>{id}</code> could not be set down.', item.value)
              if (errMsg) message += ` (${errMsg})`
              store.dispatch('notification/danger', { message })
            })
        }
      },
      {
        value: true, label: i18n.t('Up'),
        color: 'var(--success)', icon: 'check',
        promise: (value, props, context) => {
          const { item } = toRefs(props)
          const { id } = item.value
          return store.dispatch(`$_interfaces/upInterface`, id)
            .then(() => {
              context.emit('input', 'up')
              store.dispatch('notification/info', { message: i18n.t('Interface <code>{id}</code> up.', item.value) })
            })
            .catch(err => {
              const { response: { data: { message: errMsg } = {} } = {} } = err
              let message = i18n.t('Interface <code>{id}</code> could not be set up.', item.value)
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
