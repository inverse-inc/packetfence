import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  defaultsFromMeta as useItemDefaults
} from '../../../_config/'

const useItemTitle = (props) => {
  const {
    id,
    isClone,
    isNew
  } = toRefs(props)
  return computed(() => {
    switch (true) {
      case !isNew.value && !isClone.value:
        return i18n.t('EAP Profile <code>{id}</code>', { id: id.value })
      case isClone.value:
        return i18n.t('Clone EAP Profile <code>{id}</code>', { id: id.value })
      default:
        return i18n.t('New EAP Profile')
    }
  })
}

const useRouter = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $router } = {} } = context
  return {
    goToCollection: () => $router.push({ name: 'radiusEaps' }),
    goToItem: () => $router.push({ name: 'radiusEap', params: { id: form.value.id || id.value } })
      .catch(e => { if (e.name !== "NavigationDuplicated") throw e }),
    goToClone: () => $router.push({ name: 'cloneRadiusEap', params: { id: id.value } }),
  }
}

const useStore = (props, context, form) => {
  const {
    id,
    isClone
  } = toRefs(props)
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_radius_eap/isLoading']),
    getOptions: () => $store.dispatch('$_radius_eap/options'),
    createItem: () => $store.dispatch('$_radius_eap/createRadiusEap', form.value),
    deleteItem: () => $store.dispatch('$_radius_eap/deleteRadiusEap', id.value),
    getItem: () => $store.dispatch('$_radius_eap/getRadiusEap', id.value).then(item => {
      if (isClone.value) {
        item.id = `${item.id}-${i18n.t('copy')}`
        item.not_deletable = false
      }
      return item
    }),
    ...((id.value === 'default' && !isClone.value)
      ? {} // don't update id: default
      : {
        updateItem: () => $store.dispatch('$_radius_eap/updateRadiusEap', form.value)
      }
    )
  }
}

export default {
  useItemDefaults,
  useItemTitle,
  useRouter,
  useStore,
}
