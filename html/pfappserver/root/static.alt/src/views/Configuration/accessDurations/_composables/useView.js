import { computed, watch } from '@vue/composition-api'
import { useView as useBaseView, useViewProps as useBaseViewProps } from '@/composables/useView'
import i18n from '@/utils/locale'
import {
  composeDuration,
  serializeDuration
} from '../config'

const useViewProps = useBaseViewProps

const useView = (props, context) => {

  const { root: { $store } = {} } = context

  const {
    rootRef,
    form,
    meta,
    customProps,
    isValid
  } = useBaseView(props, context)

  const titleLabel = computed(() => i18n.t('Access Duration'))

  const isLoading = computed(() => $store.getters['$_bases/isLoading'])

  const doInit = () => {
    $store.dispatch('$_bases/optionsGuestsAdminRegistration').then(options => {
      const { meta: _meta = {} } = options
      meta.value = _meta
      $store.dispatch('$_bases/getGuestsAdminRegistration').then(_form => {
        const { access_duration_choices = '' } = _form
        // split and deserialize access_duration_choices
        _form.access_duration_choices = access_duration_choices.split(',').map(duration => composeDuration(duration))
        form.value = _form
      }).catch(() => {
        form.value = {}
      })
    }).catch(() => {
      form.value = {}
      meta.value = {}
    })
  }

  const doReset = doInit

  const doSave = () => {
    let { access_duration_choices = [] } = form.value
    access_duration_choices = access_duration_choices.map(duration => serializeDuration(duration)).join(',')
    $store.dispatch('$_bases/updateGuestsAdminRegistration', { ...form.value, access_duration_choices })
  }

  watch(props, () => doInit(), { deep: true, immediate: true })

  return {
    rootRef,

    form,
    meta,
    customProps,
    titleLabel,

    isLoading,
    isValid,

    doInit,
    doReset,
    doSave
  }
}

export {
  useViewProps,
  useView
}
