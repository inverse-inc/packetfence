import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useTitle = () => i18n.t('Inline')

export const useTitleHelp = () => 'PacketFence_Installation_Guide.html#_technical_introduction_to_inline_enforcement'

export const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsInline'),
    getItem: () => $store.dispatch('$_bases/getInline'),
    updateItem: () => {
      return $store.dispatch('$_bases/updateInline', form.value)
    }
  }
}
