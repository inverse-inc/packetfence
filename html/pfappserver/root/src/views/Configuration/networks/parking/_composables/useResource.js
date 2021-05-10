import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Parking')

export const useTitleHelp = () => 'PacketFence_Installation_Guide.html#_parked_devices'

export const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsParking'),
    getItem: () => $store.dispatch('$_bases/getParking'),
    updateItem: () => {
      return $store.dispatch('$_bases/updateParking', form.value)
    }
  }
}
