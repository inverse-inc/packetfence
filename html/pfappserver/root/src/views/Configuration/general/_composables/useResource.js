import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('General')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getGeneral'),
    getItemOptions: () => $store.dispatch('$_bases/optionsGeneral'),
    updateItem: params => $store.dispatch('$_bases/updateGeneral', params)
  }
}
