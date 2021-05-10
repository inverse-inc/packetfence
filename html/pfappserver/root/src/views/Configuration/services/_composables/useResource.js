import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Services')

export const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsServices'),
    getItem: () => $store.dispatch('$_bases/getServices'),
    updateItem: () => {
      return $store.dispatch('$_bases/updateServices', form.value)
    }
  }
}
