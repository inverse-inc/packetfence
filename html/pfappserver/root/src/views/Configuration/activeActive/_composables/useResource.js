import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Active Active')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getActiveActive'),
    getItemOptions: () => $store.dispatch('$_bases/optionsActiveActive'),
    updateItem: params => $store.dispatch('$_bases/updateActiveActive', params)
  }
}
