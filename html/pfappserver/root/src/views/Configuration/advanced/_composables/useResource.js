import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Advanced')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getAdvanced'),
    getItemOptions: () => $store.dispatch('$_bases/optionsAdvanced'),
    updateItem: params => $store.dispatch('$_bases/updateAdvanced', params)
  }
}
