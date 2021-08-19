<template>
  <b-tab :title="$t('Fingerbank')">
    <b-row>
      <b-col v-if="node">
        <pf-form-row class="text-nowrap" :column-label="$t('Device Class')">
          {{ node.device_class }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Device Manufacturer')">
          {{ node.device_manufacturer }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Device Type')">
          {{ node.device_type }}
        </pf-form-row>
        <pf-form-row :column-label="$t('Fully Qualified Device Name')">
          {{ node.fingerbank.device_fq }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Version')">
          {{ node.fingerbank.version }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Score')" v-if="node.fingerbank.score">
          <icon-score class="col-12 col-md-6 col-lg-3" :score="node.fingerbank.score" />
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('Mobile')">
          <div v-if="node.fingerbank.mobile === 1">
            <icon class="mr-1" name="check-square"></icon> {{ $t('Yes') }}
          </div>
          <div v-else-if="node.fingerbank.mobile === 0">
            <icon class="mr-1" name="regular/square"></icon> {{ $t('No') }}
          </div>
          <div v-else class="text-muted">
            {{ $t('Unknown') }}
          </div>
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('DHCP Fingerprint')">
          {{ node.dhcp_fingerprint }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('DHCP Vendor')">
          {{ node.dhcp_vendor }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('DHCPv6 Fingerprint')">
          {{ node.dhcp6_fingerprint }}
        </pf-form-row>
        <pf-form-row class="text-nowrap" :column-label="$t('DHCPv6 Enterprise')">
          {{ node.dhcp6_enterprise }}
        </pf-form-row>
      </b-col>
    </b-row>
    <div class="mt-3">
      <div class="border-top pt-3">
        <b-button class="mr-1" size="sm" variant="outline-secondary" :disabled="isLoading" @click="refreshFingerbank">{{ $i18n.t('Refresh Fingerbank') }}</b-button>
      </div>
    </div>
  </b-tab>
</template>
<script>
import IconScore from '@/components/IconScore'
import pfFormRow from '@/components/pfFormRow'

const components = {
  IconScore,
  pfFormRow
}

const props = {
  id: {
    type: String
  }
}

import { computed, toRefs } from '@vue/composition-api'
import { usePropsWrapper } from '@/composables/useProps'
import { useStore } from '../_composables/useCollection'

const setup = (props, context) => {

  const { id } = toRefs(props)
  const { root: { $store } = {} } = context

  const node = computed(() => $store.state.$_nodes.nodes[id.value])

  // merge props w/ params in useStore methods
  const _useStore = $store => usePropsWrapper(useStore($store), props)
  const {
    isLoading,
    refreshFingerbank
  } = _useStore($store)

  return {
    node,
    isLoading,
    refreshFingerbank
  }
}
// @vue/component
export default {
  name: 'tab-fingerbank',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>