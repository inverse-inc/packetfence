import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Captive Portal')

export const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsCaptivePortal'),
    getItem: () => $store.dispatch('$_bases/getCaptivePortal'),
    updateItem: () => {
      return $store.dispatch('$_bases/updateCaptivePortal', form.value)
    }
  }
}
