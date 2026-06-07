<template>
  <b-form @submit.prevent="onSubmit" class="p-3">
    <b-row>
      <b-col md="4">
        <small>{{ $t('MAC address') }}</small>
        <b-form-input v-model="mac" placeholder="aa:bb:cc:dd:ee:ff" />
      </b-col>
      <b-col md="8">
        <small>{{ $t('Attributes (key=value, comma-separated)') }}</small>
        <b-form-input v-model="paramsInput" placeholder="last_ssid=corp, last_switch=10.0.0.1" />
        <small class="text-muted">{{ $t('Keys must match [A-Za-z0-9_-]+; malformed entries are dropped server-side.') }}</small>
      </b-col>
    </b-row>
    <b-button type="submit" variant="primary" class="mt-3" :disabled="isLoading || !mac">
      <icon v-if="isLoading" name="circle-notch" spin class="mr-1" />
      <icon v-else name="play" class="mr-1" />
      {{ $t('Test profile filter') }}
    </b-button>
  </b-form>
</template>

<script>
import { ref } from '@vue/composition-api'

const props = { isLoading: { type: Boolean, default: false } }

const setup = (props, context) => {
  const mac = ref('')
  const paramsInput = ref('')

  const onSubmit = () => {
    const params = {}
    for (const pair of paramsInput.value.split(',').map(s => s.trim()).filter(Boolean)) {
      const idx = pair.indexOf('=')
      if (idx > 0) {
        params[pair.slice(0, idx).trim()] = pair.slice(idx + 1).trim()
      }
    }
    context.emit('submit', { mac: mac.value, params })
  }
  return { mac, paramsInput, onSubmit }
}

export default { name: 'the-form-profile-filter', props, setup }
</script>
