import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

const useTitle = () => i18n.t('Alerting')

const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsAlerting'),
    getItem: () => $store.dispatch('$_bases/getAlerting'),
    updateItem: () => {
      return $store.dispatch('$_bases/updateAlerting', form.value)
    }
  }
}

export default {
  useTitle,
  useStore,
}
