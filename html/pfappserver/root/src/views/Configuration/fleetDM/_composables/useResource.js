import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('FleetDM')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getFleetDM'),
    getItemOptions: () => $store.dispatch('$_bases/optionsFleetDM'),
    updateItem: params => $store.dispatch('$_bases/updateFleetDM', params)
  }
}
