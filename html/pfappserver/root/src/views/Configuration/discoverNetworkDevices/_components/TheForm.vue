<template>
  <b-form @submit.prevent="onSubmit" ref="formRef">
    <b-form-row>
      <b-col sm="12" md="4">
        <b-form-group
          :label="$t('CIDR Address')"
          :state="customAddressState"
          :invalid-feedback="customAddressError"
          label-class="text-left"
        >
          <b-form-input
            v-model="form.customAddress"
            :disabled="isScanning"
            :state="customAddressState"
            :placeholder="$t('e.g., 10.0.0.0/24')"
          />
        </b-form-group>
      </b-col>

      <b-col sm="12" md="4">
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
      </b-col>

      <b-col sm="12" md="4">
        <b-form-group
          :label="$t('Community String')"
          :state="snmpCommunityState"
          :invalid-feedback="snmpCommunityError"
          label-class="text-left"
        >
          <b-form-input
            v-model="form.snmpCommunity"
            :disabled="isScanning"
            :state="snmpCommunityState"
            :placeholder="$t('e.g., public')"
          />
        </b-form-group>
      </b-col>
    </b-form-row>

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
    <b-button
      v-if="!isScanning"
      type="submit"
      variant="primary"
      :disabled="!isValid"
    >
      <icon name="search" class="mr-1" />
      {{ $t('Start Discovery') }}
    </b-button>
  </b-form>
</template>

<script>
import { computed, ref } from '@vue/composition-api'
import Multiselect from 'vue-multiselect'
import i18n from '@/utils/locale'
import { reCidr } from '@/utils/regex'
import { reSnmpCommunity } from '../schema'

const components = {
  Multiselect
}

const props = {
  isScanning: {
    type: Boolean,
    default: false
  }
}

const setup = (props, context) => {
  const formRef = ref(null)
  const form = ref({
    customAddress: '',
    snmpVersion: 'snmp_v2c',
    snmpCommunity: '',
    maxThreads: 32,
    snmpTimeout: 1,
    snmpRetry: 1
  })

  const snmpVersionOptions = [
    { value: 'snmp_v1', text: 'SNMP v1' },
    { value: 'snmp_v2c', text: 'SNMP v2c' }
  ]

  const selectedSnmpVersion = ref(snmpVersionOptions[1]) // default to v2c

  const onSnmpVersionSelect = (option) => {
    form.value.snmpVersion = option ? option.value : 'snmp_v2c'
  }

  const hasAddress = computed(() => {
    return form.value.customAddress && form.value.customAddress.trim() !== ''
  })

  // Validate custom address field
  const customAddressState = computed(() => {
    if (!form.value.customAddress || form.value.customAddress.trim() === '') return null
    return reCidr(form.value.customAddress)
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

  const onSubmit = () => {
    if (!isValid.value) return

    const address = form.value.customAddress
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
    snmpVersionOptions,
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
    onSnmpVersionSelect,
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
