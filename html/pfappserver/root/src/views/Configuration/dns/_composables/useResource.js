import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('DNS Configuration')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getDnsConfiguration'),
    getItemOptions: () => $store.dispatch('$_bases/optionsDnsConfiguration'),
    updateItem: params => $store.dispatch('$_bases/updateDnsConfiguration', params)
  }
}
