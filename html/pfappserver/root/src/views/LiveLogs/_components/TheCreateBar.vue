<template>
  <b-form @submit.prevent="onCreate" ref="formRef" class="live-logs-create-bar px-3 py-2 border-bottom bg-light">
    <base-form :form="form" :schema="schema" :isLoading="isLoading">
      <div class="d-flex align-items-start">
        <div class="flex-fill mr-2 min-w-0">
          <base-input-chosen-multiple namespace="files"
            :placeholder="$t('Log Files...')"
            :options="files" />
        </div>
        <div class="flex-fill mr-2 min-w-0">
          <base-input namespace="filter"
            :placeholder="$t('Filter')" />
        </div>
        <div class="d-flex align-items-center flex-shrink-0 mr-3" style="min-height: calc(1.5em + .75rem + 2px)">
          <span class="mr-2 small text-nowrap text-muted">{{ $t('Regexp') }}</span>
          <base-input-toggle-false-true namespace="filter_is_regexp" />
        </div>
        <div class="flex-shrink-0" style="min-height: calc(1.5em + .75rem + 2px); display: flex; align-items: center">
          <b-button variant="primary" type="submit" :disabled="isLoading || !isValid" size="sm">
            <icon v-if="isLoading" name="circle-notch" spin class="mr-1" />
            {{ $t('Start Session') }}
          </b-button>
        </div>
      </div>
    </base-form>
  </b-form>
</template>

<script>
import {
  BaseForm,
  BaseInput,
  BaseInputChosenMultiple,
  BaseInputToggleFalseTrue
} from '@/components/new/'

const components = {
  BaseForm,
  BaseInput,
  BaseInputChosenMultiple,
  BaseInputToggleFalseTrue
}

import { computed, ref } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schema = yup.object({
  files: yup.array().ensure()
    .required(i18n.t('Log file(s) required.'))
    .of(yup.string().nullable())
})

const setup = (props, context) => {
  const { root: { $router, $store } = {} } = context

  const form = ref({
    name: i18n.t('New Session'),
    files: [],
    filter: null,
    filter_is_regexp: false
  })
  const formRef = ref(null)
  const files = ref([])
  const isLoading = computed(() => $store.getters['$_live_logs/isLoading'])
  const isValid = useDebouncedWatchHandler(
    [form],
    () => (!formRef.value || formRef.value.querySelectorAll('.is-invalid').length === 0)
  )

  $store.dispatch('$_live_logs/optionsSession').then(response => {
    const { meta: { files: { item: { allowed = [] } = {} } = {} } = {} } = response
    if (allowed) {
      files.value = allowed
        .map(({ text, value }) => ({ text: `${value} - ${text}`, value }))
        .sort((a, b) => a.value.localeCompare(b.value))
    }
  })

  const onCreate = () => {
    $store.dispatch('$_live_logs/createSession', form.value).then(response => {
      const { session_id } = response
      if (session_id) {
        form.value.files = []
        form.value.filter = null
        form.value.filter_is_regexp = false
        $router.push({ name: 'live_log', params: { id: session_id } })
      }
    })
  }

  return {
    form,
    formRef,
    files,
    schema,
    isLoading,
    isValid,
    onCreate
  }
}

// @vue/component
export default {
  name: 'the-create-bar',
  inheritAttrs: false,
  components,
  setup
}
</script>
