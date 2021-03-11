import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

const useTitle = () => i18n.t('Cisco Mobility Services Engine')

const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsMseTab'),
    getItem: () => $store.dispatch('$_bases/getMseTab'),
    updateItem: () => {
      return $store.dispatch('$_bases/updateMseTab', form.value)
    }
  }
}

export default {
  useTitle,
  useStore,
}
