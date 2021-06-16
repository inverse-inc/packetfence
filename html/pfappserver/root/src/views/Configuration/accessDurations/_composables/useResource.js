import { computed } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  composeDuration,
  serializeDuration
} from '../config'

export const useTitle = () => i18n.t('Access Duration')

export const useStore = $store => {
  return {
    isLoading: computed(() => $store.getters['$_bases/isLoading']),
    getItem: () => $store.dispatch('$_bases/getGuestsAdminRegistration').then(resource => {
        const { access_duration_choices = '' } = resource
        return { ...resource,
          access_duration_choices: access_duration_choices.split(',').map(duration => composeDuration(duration))
        }
    }),
    getItemOptions: () => $store.dispatch('$_bases/optionsGuestsAdminRegistration'),
    updateItem: params => {
      const { access_duration_choices = [] } = params
      return $store.dispatch('$_bases/updateGuestsAdminRegistration', { ...params,
        access_duration_choices: access_duration_choices.map(duration => serializeDuration(duration)).join(',')
      })
    }
  }
}
