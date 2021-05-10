import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Fingerbank device change detection')

export const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsFingerbankDeviceChange'),
    getItem: () => $store.dispatch('$_bases/getFingerbankDeviceChange'),
    updateItem: () => $store.dispatch('$_bases/updateFingerbankDeviceChange', form.value)
  }
}
