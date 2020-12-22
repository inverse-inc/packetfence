import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

const useTitle = () => i18n.t('Parking')

const useTitleHelp = () => 'PacketFence_Installation_Guide.html#_parked_devices'

const useStore = (props, context, form) => {
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

export default {
  useTitle,
  useTitleHelp,
  useStore,
}
