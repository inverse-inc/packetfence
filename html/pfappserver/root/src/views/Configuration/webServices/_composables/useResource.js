import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Web Services')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getWebServices'),
    getItemOptions: () => $store.dispatch('$_bases/optionsWebServices'),
    updateItem: params => $store.dispatch('$_bases/updateWebServices', params)
  }
}
