import { computed, customRef, ref, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const defaults = () => ({ // use function to avoid reactive poisoning of defaults
  country: undefined,
  state: undefined,
  locality: undefined,
  organization_name: undefined,
  common_name: undefined
})

const schema = yup.object({
  country: yup.string().required(i18n.t('Country required.')),
  state: yup.string().required(i18n.t('State required.')),
  locality: yup.string().required(i18n.t('Locality required.')),
  organization_name: yup.string().required(i18n.t('Organization name required.')),
  common_name: yup.string().required(i18n.t('Common name required.'))
})

const useCsrProps = {
  id: {
    type: String
  },
  value: { // v-model: show/hide
    type: Boolean
  },
}

const useCsr = (props, context) => {

  const { root: { $store } = {}, emit } = context

  const {
    id,
    value,
  } = toRefs(props)

  const title = computed(() => i18n.t('Generate Signing Request for {certificate} certificate', { certificate: id.value.toUpperCase() }))

  const form = ref(defaults())

// !!!
const isLoading = ref(false)

  const show = customRef((track, trigger) => ({ // use v-model
    get() {
      track()
      return value.value
    },
    set(newValue) {
      emit('input', newValue)
      trigger()
    }
  }))

  const reset = () => {
    form.value = defaults() // reset form when shown/hidden
  }

  const doHide = () => {
    show.value = false
  }

  return {
    title,
    form,
    schema,
    isLoading,

    show,
    reset,
    doHide
  }
}

export {
  useCsrProps,
  useCsr
}
