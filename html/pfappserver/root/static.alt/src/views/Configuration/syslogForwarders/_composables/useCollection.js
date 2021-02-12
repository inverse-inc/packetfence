import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { defaultsFromMeta } from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  },
  syslogForwarderType: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    syslogForwarderType
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), type: syslogForwarderType.value }
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
        return i18n.t('Syslog Entry: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Syslog Entry: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Syslog Entry')
    }
  })
}

const useItemTitleBadge = (props, context, form) => {
  const {
    syslogForwarderType
  } = toRefs(props)
  return computed(() => (syslogForwarderType.value || form.value.type))
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'syslogForwarders' }),
    goToItem: () => $router.push({ name: 'syslogForwarder', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneSyslogForwarder', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    syslogForwarderType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_syslog_forwarders/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_syslog_forwarders/optionsBySyslogForwarderType', syslogForwarderType.value)
      else
        return $store.dispatch('$_syslog_forwarders/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_syslog_forwarders/createSyslogForwarder', form.value),
    deleteItem: () => $store.dispatch('$_syslog_forwarders/deleteSyslogForwarder', id.value),
    getItem: () => $store.dispatch('$_syslog_forwarders/getSyslogForwarder', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_syslog_forwarders/updateSyslogForwarder', form.value),
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
