import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { defaultsFromMeta } from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  },
  syslogParserType: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    syslogParserType
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), type: syslogParserType.value }
}

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('Syslog Parser: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Syslog Parser: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Syslog Parser')
    }
  })
}

const useItemTitleBadge = (props, context, form) => {
  const {
    syslogParserType
  } = toRefs(props)
  return computed(() => (syslogParserType.value || form.value.type))
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'syslogParsers' }),
    goToItem: () => $router.push({ name: 'syslogParser', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneSyslogParser', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
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

export default {
  useItemDefaults,
  useItemProps,
  useItemTitle,
  useItemTitleBadge,
  useRouter,
  useStore,
}
