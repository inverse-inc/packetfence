import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

const useTitle = () => i18n.t('Advanced')

const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsAdvanced'),
    getItem: () => $store.dispatch('$_bases/getAdvanced')
      .then(response => {
        const { openid_attributes = '' } = response || {}
        return { ...response, openid_attributes: openid_attributes.split(',') }
      }),
    updateItem: () => {
      const { openid_attributes = [] } = form.value || {}
      return $store.dispatch('$_bases/updateAdvanced', { ...form.value, openid_attributes: openid_attributes.join(',') })
    }
  }
}

export default {
  useTitle,
  useStore,
}
