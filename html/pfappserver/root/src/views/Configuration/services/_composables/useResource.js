import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Services')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getServices'),
    getItemOptions: () => $store.dispatch('$_bases/optionsServices'),
    updateItem: params => $store.dispatch('$_bases/updateServices', params)
  }
}
