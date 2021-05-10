import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  composeDuration,
  serializeDuration
} from '../config'

export const useTitle = () => i18n.t('Access Duration')

export const useStore = (props, context, form) => {
  const { root: { $store } = {} } = context
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getOptions: () => $store.dispatch('$_bases/optionsGuestsAdminRegistration'),
    getItem: () => $store.dispatch('$_bases/getGuestsAdminRegistration').then(resource => {
        const { access_duration_choices = '' } = resource
        return { ...resource,
          access_duration_choices: access_duration_choices.split(',').map(duration => composeDuration(duration))
        }
    }),
    updateItem: () => {
      const { access_duration_choices = [] } = form.value
      return $store.dispatch('$_bases/updateGuestsAdminRegistration', { ...form.value,
        access_duration_choices: access_duration_choices.map(duration => serializeDuration(duration)).join(',')
      })
    }
  }
}
