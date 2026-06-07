<template>
  <div class="historical-logs-page">
    <div class="historical-logs-header px-3 py-2 border-bottom d-flex align-items-center">
      <h4 class="mb-0" v-t="'Historical Logs'" />
      <small v-if="isCluster" class="ml-3 text-muted">
        <icon name="cubes" class="mr-1" />{{ $t('Queries all {n} cluster nodes.', { n: nodeCount }) }}
      </small>
    </div>
    <b-form @submit.prevent="onCreate" ref="formRef" class="px-3 py-3 border-bottom bg-light">
      <base-form :form="form" :schema="schema" :isLoading="isLoading">
        <b-row class="no-gutters">
          <b-col md="6" class="pr-2">
            <small class="ml-1">{{ $t('Log Files') }}</small>
            <base-input-chosen-multiple namespace="files" :placeholder="$t('Log Files...')" :options="files" />
          </b-col>
          <b-col md="3" class="pr-2">
            <small class="ml-1">{{ $t('Start (UTC)') }}</small>
            <base-input namespace="start" :placeholder="'2026-06-01T00:00:00Z'" />
          </b-col>
          <b-col md="3">
            <small class="ml-1">{{ $t('End (UTC)') }}</small>
            <base-input namespace="end" :placeholder="'2026-06-08T00:00:00Z'" />
          </b-col>
        </b-row>
        <b-row class="no-gutters mt-2">
          <b-col md="9" class="pr-2">
            <small class="ml-1">{{ $t('Filter') }}</small>
            <base-input namespace="filter" :placeholder="$t('substring or regex')" />
          </b-col>
          <b-col md="3" class="d-flex align-items-end">
            <div class="d-flex align-items-center mr-3 mb-2">
              <span class="mr-2 small text-nowrap text-muted">{{ $t('Regexp') }}</span>
              <base-input-toggle-false-true namespace="filter_is_regexp" />
            </div>
            <b-button variant="primary" type="submit" :disabled="isLoading || !isValid" size="sm" class="mb-2 ml-auto">
              <icon v-if="isLoading" name="circle-notch" spin class="mr-1" />
              {{ $t('Load') }}
            </b-button>
          </b-col>
        </b-row>
      </base-form>
    </b-form>
  </div>
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

const isoLike = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})$/

const schema = yup.object({
  files: yup.array().ensure().required(i18n.t('Log file(s) required.')).of(yup.string().nullable()),
  start: yup.string().nullable().test('iso', i18n.t('Use ISO-8601, e.g. 2026-06-01T00:00:00Z'),
    v => !v || isoLike.test(v)),
  end: yup.string().nullable().test('iso', i18n.t('Use ISO-8601, e.g. 2026-06-01T00:00:00Z'),
    v => !v || isoLike.test(v))
})

const setup = (props, context) => {
  const { root: { $router, $store } = {} } = context

  const form = ref({
    name: i18n.t('Historical query'),
    files: [],
    filter: null,
    filter_is_regexp: false,
    start: null,
    end: null
  })
  const formRef = ref(null)
  const files = ref([])
  const isLoading = computed(() => $store.getters['$_historical_logs/isLoading'])
  const isSaas = computed(() => $store.getters['system/isSaas'])
  const isCluster = computed(() => !isSaas.value && $store.getters['cluster/isCluster'])
  const nodeCount = computed(() => {
    const servers = $store.state.cluster && $store.state.cluster.servers
    return servers ? Object.keys(servers).length : 0
  })
  const isValid = useDebouncedWatchHandler([form],
    () => (!formRef.value || formRef.value.querySelectorAll('.is-invalid').length === 0))

  $store.dispatch('$_historical_logs/optionsSession').then(response => {
    const { meta: { files: { item: { allowed = [] } = {} } = {} } = {} } = response
    if (allowed) {
      files.value = allowed
        .map(({ text, value }) => ({ text: `${value} - ${text}`, value }))
        .sort((a, b) => a.value.localeCompare(b.value))
    }
  })

  const onCreate = () => {
    $store.dispatch('$_historical_logs/createSession', form.value).then(response => {
      const { session_id } = response
      if (session_id) {
        $router.push({ name: 'historical_log', params: { id: session_id } })
      }
    })
  }

  return { form, formRef, files, schema, isLoading, isCluster, nodeCount, isValid, onCreate }
}

export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  setup
}
</script>
