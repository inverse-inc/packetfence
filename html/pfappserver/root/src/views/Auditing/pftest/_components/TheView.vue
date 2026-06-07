<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'pftest'" />
      <p class="text-muted mb-0">
        {{ $t('Diagnostic helpers from the pftest CLI. Runs on every cluster node and aggregates the per-host output.') }}
      </p>
    </b-card-header>
    <b-tabs v-model="tabIdx" card class="mt-1" @input="onTabChange">
      <b-tab :title="$t('Authentication')">
        <the-form-authentication @submit="onRunAuthentication" :isLoading="isLoading" />
      </b-tab>
      <b-tab :title="$t('Profile Filter')">
        <the-form-profile-filter @submit="onRunProfileFilter" :isLoading="isLoading" />
      </b-tab>
    </b-tabs>
    <the-results :results="results" v-if="results.length" />
  </b-card>
</template>

<script>
import { computed, ref } from '@vue/composition-api'
import TheFormAuthentication from './TheFormAuthentication.vue'
import TheFormProfileFilter from './TheFormProfileFilter.vue'
import TheResults from './TheResults.vue'

const components = { TheFormAuthentication, TheFormProfileFilter, TheResults }

const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const tabIdx = ref(0)
  const isLoading = computed(() => $store.getters['$_pftest/isLoading'])
  const results = computed(() => $store.getters['$_pftest/results'])

  const onTabChange = idx => {
    $store.dispatch('$_pftest/setSubcmd', idx === 1 ? 'profile_filter' : 'authentication')
  }
  const onRunAuthentication = body => $store.dispatch('$_pftest/runAuthentication', body)
  const onRunProfileFilter = body => $store.dispatch('$_pftest/runProfileFilter', body)

  return { tabIdx, isLoading, results, onTabChange, onRunAuthentication, onRunProfileFilter }
}

export default {
  name: 'the-view',
  components,
  setup
}
</script>
