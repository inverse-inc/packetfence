<template>
  <b-modal v-model="show" :title="$t('Token usage')" size="lg" hide-footer @show="onShow">
    <p class="text-muted" v-t="'Daily and monthly LLM token consumption.'" />
    <b-alert :show="!!loadError" variant="danger">{{ $t('Could not load usage.') }} {{ loadError }}</b-alert>
    <b-tabs v-model="tab" small v-if="!loadError">
      <b-tab :title="$t('Daily')" />
      <b-tab :title="$t('Monthly')" />
    </b-tabs>
    <b-table v-if="!loadError" :items="items" :fields="fields" :busy="isLoading" small striped show-empty
      :empty-text="$t('No usage data yet. Tokens are recorded after each message.')">
      <template #table-busy>
        <div class="text-center"><icon name="circle-notch" spin /></div>
      </template>
    </b-table>
  </b-modal>
</template>

<script>
import { computed, customRef, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'

const props = {
  value: {
    type: Boolean
  }
}

const number = value => (value === null || value === undefined) ? '-' : value.toLocaleString()

const setup = (props, context) => {
  const { emit } = context

  const show = customRef((track, trigger) => ({ // use v-model
    get() {
      track()
      return props.value
    },
    set(newValue) {
      emit('input', newValue)
      trigger()
    }
  }))

  const tab = ref(0)
  const usage = ref({})
  const isLoading = ref(false)
  const loadError = ref('')
  const onShow = () => {
    isLoading.value = true
    loadError.value = ''
    api.usage().then(response => { usage.value = response || {} }).catch(err => {
      usage.value = {}
      const { response: { status, data: { error, message } = {} } = {} } = err || {}
      loadError.value = error || message || (status ? `HTTP ${status}` : '')
    }).finally(() => { isLoading.value = false })
  }

  const items = computed(() => (tab.value === 0 ? usage.value.daily : usage.value.monthly) || [])
  const fields = computed(() => [
    { key: tab.value === 0 ? 'date' : 'month', label: tab.value === 0 ? i18n.t('Date') : i18n.t('Month') },
    { key: 'input_tokens', label: i18n.t('Input'), class: 'text-right', formatter: number },
    { key: 'output_tokens', label: i18n.t('Output'), class: 'text-right', formatter: number },
    { key: 'total_tokens', label: i18n.t('Total'), class: 'text-right font-weight-bold', formatter: number }
  ])

  return { show, tab, isLoading, loadError, onShow, items, fields }
}

// @vue/component
export default {
  name: 'the-usage',
  props,
  setup
}
</script>
