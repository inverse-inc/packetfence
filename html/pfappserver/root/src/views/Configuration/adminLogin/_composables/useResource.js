import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Admin Login')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getAdminLogin'),
    getItemOptions: () => $store.dispatch('$_bases/optionsAdminLogin'),
    updateItem: params => $store.dispatch('$_bases/updateAdminLogin', params)
  }
}
