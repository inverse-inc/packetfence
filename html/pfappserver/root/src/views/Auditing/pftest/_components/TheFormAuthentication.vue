<template>
  <b-form @submit.prevent="onSubmit" class="p-3">
    <b-row>
      <b-col md="4">
        <small>{{ $t('Username') }}</small>
        <b-form-input v-model="user" autocomplete="off" />
      </b-col>
      <b-col md="4">
        <small>{{ $t('Password') }}</small>
        <b-form-input ref="passwordInput" type="password" autocomplete="new-password"
          :value="password" @input="onPasswordInput" />
        <small class="text-muted">{{ $t('Sent over HTTPS and redacted from the admin audit log.') }}</small>
      </b-col>
      <b-col md="4">
        <small>{{ $t('Sources (optional)') }}</small>
        <b-form-input v-model="sourcesInput" :placeholder="$t('comma-separated source IDs')" />
        <small class="text-muted">{{ $t('Empty = all configured sources.') }}</small>
      </b-col>
    </b-row>
    <b-button type="submit" variant="primary" class="mt-3"
      :disabled="isLoading || !user || !password">
      <icon v-if="isLoading" name="circle-notch" spin class="mr-1" />
      <icon v-else name="play" class="mr-1" />
      {{ $t('Test authentication') }}
    </b-button>
  </b-form>
</template>

<script>
import { ref } from '@vue/composition-api'

const props = { isLoading: { type: Boolean, default: false } }

const setup = (props, context) => {
  const user = ref('')
  // Password is intentionally kept out of the Vuex store so it does not
  // survive route navigation / persist in localStorage. Cleared on submit.
  const password = ref('')
  const passwordInput = ref(null)
  const sourcesInput = ref('')

  const onPasswordInput = v => { password.value = v }
  const onSubmit = () => {
    const sources = sourcesInput.value.split(',').map(s => s.trim()).filter(Boolean)
    context.emit('submit', {
      user: user.value,
      password: password.value,
      sources
    })
    // Wipe immediately so it does not linger in component state.
    password.value = ''
    if (passwordInput.value && passwordInput.value.$el) {
      const el = passwordInput.value.$el
      if (el.tagName === 'INPUT') el.value = ''
    }
  }
  return { user, password, sourcesInput, onPasswordInput, onSubmit, passwordInput }
}

export default { name: 'the-form-authentication', props, setup }
</script>
