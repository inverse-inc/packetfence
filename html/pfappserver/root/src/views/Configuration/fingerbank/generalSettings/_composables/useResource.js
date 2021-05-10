import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('General Settings')

export const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_fingerbank/isGeneralSettingsLoading']),
    getOptions: () => $store.dispatch('$_fingerbank/optionsGeneralSettings'),
    getItem: () => $store.dispatch('$_fingerbank/getGeneralSettings'),
    updateItem: () => $store.dispatch('$_fingerbank/setGeneralSettings', form.value)
  }
}
