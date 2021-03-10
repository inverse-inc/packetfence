import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

const useTitle = () => i18n.t('General Configuration')

const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsRadiusConfiguration'),
    getItem: () => $store.dispatch('$_bases/getRadiusConfiguration'),
    updateItem: () => {
      return $store.dispatch('$_bases/updateRadiusConfiguration', form.value)
    }
  }
}

export default {
  useTitle,
  useStore,
}
