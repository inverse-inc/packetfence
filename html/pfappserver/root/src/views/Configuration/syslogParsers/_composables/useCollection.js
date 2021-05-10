import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemProps = {
  id: {
    type: String
  },
  syslogParserType: {
    type: String
  }
}

import { useDefaultsFromMeta } from '@/composables/useMeta'
export const useItemDefaults = (meta, props) => {
  const {
    syslogParserType
  } = toRefs(props)
  return { ...useDefaultsFromMeta(meta), type: syslogParserType.value }
}

export const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Syslog Parser <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Syslog Parser <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Syslog Parser')
    }
  })
}

export const useItemTitleBadge = (props, context, form) => {
  const {
    syslogParserType
  } = toRefs(props)
  return computed(() => (syslogParserType.value || form.value.type))
}

export { useRouter } from '../_router'

export const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    syslogParserType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_syslog_parsers/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_syslog_parsers/optionsBySyslogParserType', syslogParserType.value)
      else
        return $store.dispatch('$_syslog_parsers/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_syslog_parsers/createSyslogParser', form.value),
    deleteItem: () => $store.dispatch('$_syslog_parsers/deleteSyslogParser', id.value),
    getItem: () => $store.dispatch('$_syslog_parsers/getSyslogParser', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_syslog_parsers/updateSyslogParser', form.value),
  }
}
