<template>
  <b-card no-body>
    <b-card-header>
      <h4 v-t="'Live Logs'" class="mb-0" />
    </b-card-header>
    <the-tabs />
    <b-card-body>
      <b-form @submit.prevent="onCreate" ref="formRef">
        <base-form
          :form="form"
          :schema="schema"
          :isLoading="isLoading"
        >
          <b-form-row align-v="center">
            <b-col sm="12">
              <base-form-group-chosen-multiple namespace="files"
                :column-label="$t('Log Files')"
                :placeholder="$t('Choose log file(s)')"
                :options="files" />
              <base-form-group-input namespace="filter"
                :column-label="$t('Filter')" />
              <base-form-group-toggle-false-true namespace="filter_is_regexp"
                :column-label="$t('Regular Expression')" />
            </b-col>
          </b-form-row>
        </base-form>
      </b-form>
    </b-card-body>
    <b-card-footer>
      <b-button variant="primary" :disabled="isLoading || !isValid" @click="onCreate">
        <icon name="circle-notch" spin v-show="isLoading" /> {{ $t('Start Session') }}
      </b-button>
    </b-card-footer>
  </b-card>
</template>

<script>
import {
  BaseForm,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput,
  BaseFormGroupToggleFalseTrue
} from '@/components/new/'
import TheTabs from './TheTabs'

const components = {
  BaseForm,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput,
  BaseFormGroupToggleFalseTrue,
  TheTabs
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

  const form = ref ({
    name: i18n.t('New Session'),
    files: [],
    filter: null,
    filter_is_regexp: false
  })
  const formRef = ref(null)
  const files = ref([])
  const isLoading = computed(() => $store.getters[`$_live_logs/isLoading`])
  const isValid = useDebouncedWatchHandler([form], () => (!formRef.value || formRef.value.querySelectorAll('.is-invalid').length === 0))
  const sessions = computed(() => $store.getters['$_live_logs/sessions'])

  // immediate
  $store.dispatch(`$_live_logs/optionsSession`).then(response => {
    const { meta: { files: { item: { allowed = [] } = {} } = {} } = {} } = response
    if (allowed) {
      files.value = allowed
        .map(item => {
          const { text, value } = item
          return { text: `${value} - ${text}`, value }
        })
        .sort((a, b) => {
          return a.value.localeCompare(b.value)
        })
    }
  })

  const onCreate = () => {
    $store.dispatch(`$_live_logs/createSession`, form.value).then(response => {
      const { session_id } = response
      if (session_id)
        $router.push({ name: 'live_log', params: { id: session_id } })
    })
  }

  return {
    form,
    formRef,
    files,
    schema,
    isLoading,
    isValid,
    sessions,
    onCreate
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  setup
}
</script>
