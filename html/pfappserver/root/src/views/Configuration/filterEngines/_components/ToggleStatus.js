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
          const { item, collection: _collection } = toRefs(props)
          const { id } = item.value
          const { collection } = _collection.value
          return store.dispatch('$_filter_engines/disableFilterEngine', { collection, id })
            .then(() => store.dispatch(
              'notification/info',
              { message: i18n.t('{collection} <code>{id}</code> disabled.', { collection: store.getters['$_filter_engines/collectionToName'](collection), id }) }
            ))
            .catch(() => store.dispatch(
              'notification/danger',
              { message: i18n.t('{collection} <code>{id}</code> could not be disabled.', { collection: store.getters['$_filter_engines/collectionToName'](collection), id }) }
            ))
        }
      },
      {
        value: 'enabled', label: i18n.t('Enabled'),
        color: 'var(--success)', icon: 'check',
        promise: (value, props) => {
          const { item, collection: _collection } = toRefs(props)
          const { id } = item.value
          const { collection } = _collection.value
          return store.dispatch('$_filter_engines/enableFilterEngine', { collection, id })
            .then(() => store.dispatch(
              'notification/info',
              { message: i18n.t('{collection} <code>{id}</code> enabled.', { collection: store.getters['$_filter_engines/collectionToName'](collection), id }) }
            ))
            .catch(() => store.dispatch(
              'notification/danger',
              { message: i18n.t('{collection} <code>{id}</code> could not be enabled.', { collection: store.getters['$_filter_engines/collectionToName'](collection), id }) }
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
  },
  collection: {
    type: Object
  }
}

export default {
  name: 'base-toggle-status',
  extends: BaseInputToggle,
  props
}
