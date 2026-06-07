<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'pftest'" />
      <p class="text-muted mb-0">
        {{ $t('Diagnostic helpers from the pftest CLI. Runs on every cluster node and aggregates the per-host output.') }}
      </p>
    </b-card-header>
    <b-tabs v-model="tabIdx" card class="mt-1">
      <b-tab :title="$t('Authentication')" @click="onTabAuth">
        <the-form-authentication @submit="onRunAuthentication" :isLoading="isLoading" />
      </b-tab>
      <b-tab :title="$t('Profile Filter')" @click="onTabProfile">
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

  const onTabAuth = () => $store.dispatch('$_pftest/setSubcmd', 'authentication')
  const onTabProfile = () => $store.dispatch('$_pftest/setSubcmd', 'profile_filter')

  const onRunAuthentication = body => $store.dispatch('$_pftest/runAuthentication', body)
  const onRunProfileFilter = body => $store.dispatch('$_pftest/runProfileFilter', body)

  return { tabIdx, isLoading, results, onTabAuth, onTabProfile, onRunAuthentication, onRunProfileFilter }
}

export default {
  name: 'the-view',
  components,
  setup
}
</script>
