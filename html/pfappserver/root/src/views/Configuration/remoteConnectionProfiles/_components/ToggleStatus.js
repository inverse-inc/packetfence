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
        promise: (value, props) => {
          const { item, searchableStoreName } = toRefs(props)
          return store.dispatch('$_remote_connection_profiles/disableRemoteConnectionProfile', item.value)
            .then(() => {
              // update searcahble store
              store.dispatch(`${searchableStoreName.value}/updateItem`, { key: 'id', id: item.value.id, prop: 'status', data: 'disabled' })
            })
        }
      },
      {
        value: 'enabled', label: i18n.t('Enabled'),
        color: 'var(--success)', icon: 'check',
        promise: (value, props) => {
          const { item, searchableStoreName } = toRefs(props)
          return store.dispatch('$_remote_connection_profiles/enableRemoteConnectionProfile', item.value)
            .then(() => {
              // update searcahble store
              store.dispatch(`${searchableStoreName.value}/updateItem`, { key: 'id', id: item.value.id, prop: 'status', data: 'enabled' })
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
