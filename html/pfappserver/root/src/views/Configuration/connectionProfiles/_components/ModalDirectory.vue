<template>
  <b-modal v-model="show"
    @shown="reset(true)"
    @hidden="reset"
    size="lg" body-class="p-0"
  >
    <template v-slot:modal-title>
      <span>{{ $i18n.t('Create New Directory') }}</span>
    </template>
    <template v-slot:default>
      <b-form @submit.prevent="onCreate" ref="formRef">
        <base-form
          :form="form"
          :schema="schema"
          :isLoading="isLoading"
        >
          <form-group-name ref="inputRef"
            namespace="name"
            :column-label="`${path}/`"
            :label-cols="4"
            placeholder="directory"
          />
        </base-form>
      </b-form>
    </template>
    <template v-slot:modal-footer>
      <b-button
        class="mr-1" variant="primary" :disabled="!isValid" @click="onCreate">{{ $t('Create') }}</b-button>
      <b-button class="mr-1" variant="secondary" @click="onHide">{{ $t('Cancel') }}</b-button>
    </template>
  </b-modal>
</template>
<script>
import {
  BaseForm,
  BaseFormGroupInput
} from '@/components/new/'
import {

} from './'

const components = {
  BaseForm,
  FormGroupName: BaseFormGroupInput
}

const props = {
  entries: {
    type: Array
  },
  path: {
    type: String
  },
  value: { // v-model: show/hide
    type: Boolean
  }
}

import { computed, customRef, nextTick, ref, toRefs } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventJail from '@/composables/useEventJail'
import i18n from '@/utils/locale'
import { yup } from '../schema'

const defaults = () => ({
  name: undefined
})

const setup = (props, context) => {

  const { root: { $store } = {}, emit } = context

  const {
    entries,
    path,
    value,
  } = toRefs(props)

  const schema = computed(() => yup.object({
    name: yup.string()
      .required(i18n.t('A new directory name is required.'))
      .isFilename(i18n.t('Invalid directory name.'))
      .pathNotExists(entries, path, i18n.t('Directory name exists.'))
  }))

  const form = ref(defaults())
  const formRef = ref(null)
  useEventJail(formRef)
  const isLoading = computed(() => $store.getters['$_certificates/isLoadingFiles'])

  const inputRef = ref(null)

  const isValid = useDebouncedWatchHandler(form, () => (!formRef.value || formRef.value.querySelectorAll('.is-invalid').length === 0))

  const onCreate = () => {
    if (isValid.value) {
      emit('create', form.value.name)
      show.value = false
    }
  }

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

  const reset = (shown) => {
    form.value = defaults() // reset form when shown/hidden
    if (shown) { // if showing
      nextTick(() => { // after DOM update
        const { $refs: { input: { focus = () => {} } = {} } = {} } = inputRef.value
        focus() // focus input element
      })
    }
  }

  const onHide = () => {
    show.value = false
  }

  return {
    form,
    formRef,
    schema,
    inputRef,
    isLoading,
    isValid,
    onCreate,

    show,
    reset,
    onHide
  }
}

export default {
  name: 'modal-directory',
  components,
  props,
  setup
}
</script>
