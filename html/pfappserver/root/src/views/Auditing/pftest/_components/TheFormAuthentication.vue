<template>
  <b-form @submit.prevent="onSubmit" class="p-3">
    <b-row>
      <b-col md="4">
        <small>{{ $t('Username') }}</small>
        <b-form-input v-model="user" autocomplete="off" :placeholder="$t('e.g. admin or test@example.com')" />
      </b-col>
      <b-col md="4">
        <small>{{ $t('Password (optional)') }}</small>
        <b-form-input ref="passwordInput" type="password" autocomplete="new-password"
          :value="password" @input="onPasswordInput" :placeholder="$t('leave empty for reach-test')" />
        <small class="text-muted">{{ $t('Sent over HTTPS and redacted from the admin audit log.') }}</small>
      </b-col>
      <b-col md="4">
        <small>{{ $t('Sources (optional)') }}</small>
        <multiselect v-model="selectedSources"
          :options="sourceOptions" :multiple="true" :close-on-select="false"
          :placeholder="$t('All sources') + ' (' + (sourceOptions.length || $t('loading')) + ')'"
          track-by="value" label="text"
          :loading="sourcesLoading">
          <template #option="{ option }">
            <strong>{{ option.value }}</strong> <span class="text-muted">{{ option.text }}</span>
          </template>
        </multiselect>
        <small class="text-muted">{{ $t('Pick one or more; empty = test against all configured sources.') }}</small>
      </b-col>
    </b-row>
    <b-row v-if="isCluster" class="mt-3">
      <b-col>
        <b-form-checkbox v-model="cluster">
          {{ $t('Run on all cluster nodes') }}
        </b-form-checkbox>
        <small class="text-warning">
          {{ $t('Each run performs a real authentication attempt against the configured sources on every node — repeated failures can trigger account lockout in AD/LDAP. Runs are rate-limited per tested user.') }}
        </small>
      </b-col>
    </b-row>
    <b-button type="submit" variant="primary" class="mt-3"
      :disabled="isLoading || !user">
      <icon v-if="isLoading" name="circle-notch" spin class="mr-1" />
      <icon v-else name="play" class="mr-1" />
      {{ $t('Test authentication') }}
    </b-button>
  </b-form>
</template>

<script>
import { ref, computed, onMounted } from '@vue/composition-api'
import Multiselect from 'vue-multiselect'
import api from '../_api'

const components = { Multiselect }
const props = { isLoading: { type: Boolean, default: false } }

const setup = (props, context) => {
  const { root: { $store } = {} } = context
  const isCluster = computed(() => $store.getters['cluster/isCluster'])
  const cluster = ref(false)
  const user = ref('')
  const password = ref('')
  const passwordInput = ref(null)
  const allSources = ref([])
  const sourcesLoading = ref(false)
  const selectedSources = ref([])

  const sourceOptions = computed(() => allSources.value.map(s => ({
    value: s.id,
    text: s.type ? `(${s.type})` : ''
  })))

  onMounted(() => {
    sourcesLoading.value = true
    api.listSources().then(items => {
      allSources.value = items
    }).catch(() => {}).finally(() => { sourcesLoading.value = false })
  })

  const onPasswordInput = v => { password.value = v }
  const onSubmit = () => {
    const sources = (selectedSources.value || []).map(s => s.value).filter(Boolean)
    context.emit('submit', {
      user: user.value,
      password: password.value,
      sources,
      cluster: cluster.value
    })
    password.value = ''
    if (passwordInput.value && passwordInput.value.$el) {
      const el = passwordInput.value.$el
      if (el.tagName === 'INPUT') el.value = ''
    }
  }
  return { user, password, passwordInput, selectedSources, sourceOptions, sourcesLoading, isCluster, cluster, onPasswordInput, onSubmit }
}

export default { name: 'the-form-authentication', components, props, setup }
</script>
