<template>
  <b-form @submit.prevent="onSubmit" ref="formRef">
    <!-- Network Selection -->
    <b-form-group
      :label="$t('Network to Scan')"
      :description="$t('Select a network interface or enter a custom CIDR address')"
      label-class="text-left"
    >
      <multiselect
        v-model="selectedNetwork"
        :options="networkOptions"
        :disabled="isScanning"
        :placeholder="$t('Choose a network...')"
        :show-labels="false"
        :allow-empty="true"
        :searchable="true"
        track-by="value"
        label="text"
        class="base-input-chosen"
        @select="onNetworkSelect"
        @remove="onNetworkRemove"
      />
    </b-form-group>

    <b-form-group
      :label="$t('Custom CIDR Address')"
      :description="$t('Override network selection with a custom CIDR (e.g., 10.0.0.0/24)')"
      :state="customAddressState"
      :invalid-feedback="customAddressError"
      label-class="text-left"
    >
      <b-form-input
        v-model="form.customAddress"
        :disabled="isScanning"
        :state="customAddressState"
        @input="onCustomAddressInput"
      />
    </b-form-group>

    <!-- SNMP Settings -->
    <b-form-group
      :label="$t('SNMP Version')"
      label-class="text-left"
    >
      <multiselect
        v-model="selectedSnmpVersion"
        :options="snmpVersionOptions"
        :disabled="isScanning"
        :placeholder="$t('Select version...')"
        :show-labels="false"
        :allow-empty="false"
        track-by="value"
        label="text"
        class="base-input-chosen"
        @select="onSnmpVersionSelect"
      />
    </b-form-group>

    <b-form-group
      :label="$t('Community String')"
      :description="$t('SNMP community string for read access (RFC 1157). Leave empty to skip SNMP.')"
      :state="snmpCommunityState"
      :invalid-feedback="snmpCommunityError"
      label-class="text-left"
    >
      <b-form-input
        v-model="form.snmpCommunity"
        :disabled="isScanning"
        :state="snmpCommunityState"
      />
    </b-form-group>

    <!-- Advanced Options (Collapsible) -->
    <b-card class="mb-3" no-body>
      <b-card-header header-tag="header" class="p-2">
        <b-button v-b-toggle.options-collapse variant="link" class="text-decoration-none w-100 text-left">
          <icon name="cog" class="mr-2" />
          {{ $t('Advanced Options') }}
          <icon name="chevron-down" class="float-right collapse-icon" />
        </b-button>
      </b-card-header>
      <b-collapse id="options-collapse">
        <b-card-body>
          <b-form-row>
            <b-col sm="12" md="4">
              <b-form-group
                :label="$t('Max Threads')"
                :description="$t('Parallel threads (1-128)')"
                :state="maxThreadsState"
                :invalid-feedback="maxThreadsError"
                label-class="text-left"
              >
                <b-form-input
                  v-model.number="form.maxThreads"
                  type="number"
                  min="1"
                  max="128"
                  :disabled="isScanning"
                  :state="maxThreadsState"
                />
              </b-form-group>
            </b-col>
            <b-col sm="12" md="4">
              <b-form-group
                :label="$t('Timeout')"
                :description="$t('Seconds (1-10)')"
                :state="snmpTimeoutState"
                :invalid-feedback="snmpTimeoutError"
                label-class="text-left"
              >
                <b-form-input
                  v-model.number="form.snmpTimeout"
                  type="number"
                  min="1"
                  max="10"
                  :disabled="isScanning"
                  :state="snmpTimeoutState"
                />
              </b-form-group>
            </b-col>
            <b-col sm="12" md="4">
              <b-form-group
                :label="$t('Retries')"
                :description="$t('Count (0-3)')"
                :state="snmpRetryState"
                :invalid-feedback="snmpRetryError"
                label-class="text-left"
              >
                <b-form-input
                  v-model.number="form.snmpRetry"
                  type="number"
                  min="0"
                  max="3"
                  :disabled="isScanning"
                  :state="snmpRetryState"
                />
              </b-form-group>
            </b-col>
          </b-form-row>
        </b-card-body>
      </b-collapse>
    </b-card>

    <!-- Submit Button -->
    <div class="d-flex align-items-center">
      <b-button
        type="submit"
        variant="primary"
        :disabled="isScanning || !isValid"
      >
        <icon v-if="isScanning" name="circle-notch" spin class="mr-1" />
        <icon v-else name="search" class="mr-1" />
        {{ isScanning ? $t('Scanning...') : $t('Start Discovery') }}
      </b-button>

      <div v-if="scanStatus" class="ml-3">
        <b-badge v-if="scanStatus === 'loading'" variant="info">
          <icon name="circle-notch" spin class="mr-1" />
          {{ $t('Scanning') }}
        </b-badge>
        <b-badge v-else-if="scanStatus === 'success'" variant="success">
          <icon name="check" class="mr-1" />
          {{ $t('Complete') }}
        </b-badge>
        <b-badge v-else-if="scanStatus === 'error'" variant="danger">
          <icon name="exclamation-triangle" class="mr-1" />
          {{ $t('Error') }}
        </b-badge>
      </div>
    </div>
  </b-form>
</template>

<script>
import { computed, onMounted, ref } from '@vue/composition-api'
import Multiselect from 'vue-multiselect'
import i18n from '@/utils/locale'
import { reCidr, reSnmpCommunity } from '../schema'

const components = {
  Multiselect
}

const props = {
  isScanning: {
    type: Boolean,
    default: false
  },
  scanStatus: {
    type: String,
    default: ''
  }
}

const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const formRef = ref(null)
  const form = ref({
    network: null,
    customAddress: '',
    snmpVersion: 'snmp_v2c',
    snmpCommunity: '',
    maxThreads: 32,
    snmpTimeout: 1,
    snmpRetry: 1
  })

  const interfaces = ref([])

  const snmpVersionOptions = [
    { value: 'snmp_v1', text: 'SNMP v1' },
    { value: 'snmp_v2c', text: 'SNMP v2c' }
  ]

  // Selected objects for multiselect components
  const selectedNetwork = ref(null)
  const selectedSnmpVersion = ref(snmpVersionOptions[1]) // default to v2c

  const networkOptions = computed(() => {
    return interfaces.value
      .filter(iface => iface.network)
      .map(iface => ({
        value: iface.network,
        text: `${iface.id} - ${iface.network}`
      }))
  })

  // Multiselect handlers
  const onNetworkSelect = (option) => {
    form.value.network = option ? option.value : null
    // Clear custom address when selecting from dropdown
    if (option) {
      form.value.customAddress = ''
    }
  }

  const onNetworkRemove = () => {
    form.value.network = null
    selectedNetwork.value = null
  }

  const onSnmpVersionSelect = (option) => {
    form.value.snmpVersion = option ? option.value : 'snmp_v2c'
  }

  const hasCustomAddress = computed(() => {
    return form.value.customAddress && form.value.customAddress.trim() !== ''
  })

  const hasNetworkSelected = computed(() => {
    return form.value.network !== null
  })

  const hasAddress = computed(() => {
    return hasCustomAddress.value || hasNetworkSelected.value
  })

  const effectiveAddress = computed(() => {
    return form.value.customAddress || form.value.network
  })

  // Validate custom address field
  const customAddressState = computed(() => {
    if (!form.value.customAddress || form.value.customAddress.trim() === '') return null
    return reCidr.test(form.value.customAddress)
  })

  const customAddressError = computed(() => {
    if (customAddressState.value === false) {
      return i18n.t('Invalid CIDR format. Use format like 192.168.1.0/24 (prefix /16-32)')
    }
    return ''
  })

  // Validate SNMP community string (optional, but must be valid if provided)
  const snmpCommunityState = computed(() => {
    const value = form.value.snmpCommunity
    if (!value || value.trim() === '') return null // empty is valid
    if (value.length > 255) return false
    return reSnmpCommunity.test(value)
  })

  const snmpCommunityError = computed(() => {
    const value = form.value.snmpCommunity
    if (!value || value.trim() === '') {
      return '' // empty is allowed
    }
    if (value.length > 255) {
      return i18n.t('Community string must be 255 characters or less.')
    }
    if (!reSnmpCommunity.test(value)) {
      return i18n.t('Community string must contain only printable ASCII characters (RFC 1157).')
    }
    return ''
  })

  // Validate advanced options
  const maxThreadsState = computed(() => {
    const value = form.value.maxThreads
    if (value === null || value === undefined || value === '') return null
    return value >= 1 && value <= 128
  })

  const maxThreadsError = computed(() => {
    if (maxThreadsState.value === false) {
      return i18n.t('Max threads must be between 1 and 128.')
    }
    return ''
  })

  const snmpTimeoutState = computed(() => {
    const value = form.value.snmpTimeout
    if (value === null || value === undefined || value === '') return null
    return value >= 1 && value <= 10
  })

  const snmpTimeoutError = computed(() => {
    if (snmpTimeoutState.value === false) {
      return i18n.t('Timeout must be between 1 and 10 seconds.')
    }
    return ''
  })

  const snmpRetryState = computed(() => {
    const value = form.value.snmpRetry
    if (value === null || value === undefined || value === '') return null
    return value >= 0 && value <= 3
  })

  const snmpRetryError = computed(() => {
    if (snmpRetryState.value === false) {
      return i18n.t('Retries must be between 0 and 3.')
    }
    return ''
  })

  // Overall form validity
  const isValid = computed(() => {
    const hasValidAddress = hasAddress.value && (customAddressState.value !== false)
    const hasValidCommunity = snmpCommunityState.value !== false // null (empty) or true are valid
    const hasValidOptions = maxThreadsState.value !== false &&
                           snmpTimeoutState.value !== false &&
                           snmpRetryState.value !== false
    return hasValidAddress && hasValidCommunity && hasValidOptions
  })

  // Clear network selection when typing custom address
  const onCustomAddressInput = () => {
    if (form.value.customAddress && form.value.customAddress.trim() !== '') {
      form.value.network = null
      selectedNetwork.value = null
    }
  }

  onMounted(() => {
    $store.dispatch('config/getInterfaces').then(data => {
      interfaces.value = data || []
    })
  })

  const onSubmit = () => {
    if (!isValid.value) return

    const address = effectiveAddress.value
    const payload = {
      network: address,
      addresses: [address],
      credentials: [
        {
          type: form.value.snmpVersion,
          snmp_read: form.value.snmpCommunity
        }
      ],
      options: {
        max_threads: form.value.maxThreads,
        snmp_timeout: form.value.snmpTimeout,
        snmp_retry: form.value.snmpRetry
      }
    }

    context.emit('scan', payload)
  }

  return {
    formRef,
    form,
    networkOptions,
    snmpVersionOptions,
    selectedNetwork,
    selectedSnmpVersion,
    customAddressState,
    customAddressError,
    snmpCommunityState,
    snmpCommunityError,
    maxThreadsState,
    maxThreadsError,
    snmpTimeoutState,
    snmpTimeoutError,
    snmpRetryState,
    snmpRetryError,
    isValid,
    onNetworkSelect,
    onNetworkRemove,
    onSnmpVersionSelect,
    onCustomAddressInput,
    onSubmit
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

<style scoped>
.collapse-icon {
  transition: transform 0.2s ease;
}
.collapsed .collapse-icon {
  transform: rotate(-90deg);
}
</style>
