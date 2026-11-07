import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('NACBot')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getPfchatbot'),
    getItemOptions: () => $store.dispatch('$_bases/optionsPfchatbot'),
    updateItem: params => $store.dispatch('$_bases/updatePfchatbot', params)
  }
}
