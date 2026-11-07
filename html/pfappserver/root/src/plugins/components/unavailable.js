/**
 * The composables of a page whose plugin is not registered anymore
 */
import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'

const title = () => computed(() => i18n.t('This plugin is not available.'))

export const unavailable = {
  useTitle: title,
  useItemTitle: title,
  useStore: () => ({
    isLoading: computed(() => false),
    getItem: () => Promise.reject(new Error('plugin not available'))
  })
}
