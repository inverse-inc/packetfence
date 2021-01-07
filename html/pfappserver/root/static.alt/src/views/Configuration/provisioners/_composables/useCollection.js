import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import { provisioningTypes } from '../config'
import { defaultsFromMeta } from '../../_config/'

export const useItemProps = {
  id: {
    type: String
  },
  provisioningType: {
    type: String
  }
}

const useItemDefaults = (meta, props) => {
  const {
    provisioningType
  } = toRefs(props)
  return { ...defaultsFromMeta(meta), type: provisioningType.value }
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
        return i18n.t('Provisioner: <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone Provisioner: <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New Provisioner')
    }
  })
}

const useItemTitleBadge = (props, context, form) => {
  const {
    provisioningType
  } = toRefs(props)
  return computed(() => provisioningTypes[provisioningType.value || form.value.type])
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'provisionings' }),
    goToItem: () => $router.push({ name: 'provisioning', params: { id: form.value.id || id.value } }),
    goToClone: () => $router.push({ name: 'cloneProvisioning', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone,
    isNew,
    provisioningType
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_provisionings/isLoading']),
    getOptions: () => {
      if (isNew.value)
        return $store.dispatch('$_provisionings/optionsByProvisioningType', provisioningType.value)
      else
        return $store.dispatch('$_provisionings/optionsById', id.value)
    },
    createItem: () => $store.dispatch('$_provisionings/createProvisioning', form.value),
    deleteItem: () => $store.dispatch('$_provisionings/deleteProvisioning', id.value),
    getItem: () => $store.dispatch('$_provisionings/getProvisioning', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    updateItem: () => $store.dispatch('$_provisionings/updateProvisioning', form.value),
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
