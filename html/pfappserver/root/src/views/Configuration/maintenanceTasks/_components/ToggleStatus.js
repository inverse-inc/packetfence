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
          return store.dispatch('$_maintenance_tasks/disableMaintenanceTask', item.value)
            .then(() => {
              context.emit('input', 'disabled')
              store.dispatch(
                'notification/info',
                { message: i18n.t('Maintenance Task <code>{id}</code> disabled.', item.value) }
              )
            })
            .catch(() => store.dispatch(
              'notification/danger',
              { message: i18n.t('Maintenance Task <code>{id}</code> could not be disabled.', item.value) }
            ))
        }
      },
      {
        value: 'enabled', label: i18n.t('Enabled'),
        color: 'var(--success)', icon: 'check',
        promise: (value, props, context) => {
          const { item } = toRefs(props)
          return store.dispatch('$_maintenance_tasks/enableMaintenanceTask', item.value)
            .then(() => {
              context.emit('input', 'enabled')
              store.dispatch(
                'notification/info',
                { message: i18n.t('Maintenance Task <code>{id}</code> enabled.', item.value) }
              )
            })
            .catch(() => store.dispatch(
              'notification/danger',
              { message: i18n.t('Maintenance Task <code>{id}</code> could not be enabled.', item.value) }
            ))

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
