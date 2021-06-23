import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Parking')

export const useTitleHelp = () => 'PacketFence_Installation_Guide.html#_parked_devices'

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getParking'),
    getItemOptions: () => $store.dispatch('$_bases/optionsParking'),
    updateItem: params => $store.dispatch('$_bases/updateParking', params)
  }
}
