import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Networking')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getNetwork'),
    getItemOptions: () => $store.dispatch('$_bases/optionsNetwork'),
    updateItem: params => $store.dispatch('$_bases/updateNetwork', params)
  }
}
