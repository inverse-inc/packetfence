<template>
  <b-tab title="Option82">
    <template v-slot:title>
      {{ $t('Option82') }} <b-badge pill v-if="node && node.dhcpoption82 && node.dhcpoption82.length > 0" variant="light" class="ml-1">{{ node.dhcpoption82.length }}</b-badge>
    </template>
    <b-table v-if="node && node.dhcpoption82"
      :items="node.dhcpoption82" :fields="dhcpOption82Fields" :sortBy="dhcpOption82SortBy" :sortDesc="dhcpOption82SortDesc" responsive show-empty sort-icon-left striped>
      <template v-slot:empty>
        <pf-empty-table :is-loading="isLoading" text="">{{ $t('No DHCP option82 logs found') }}</pf-empty-table>
      </template>
    </b-table>
  </b-tab>
</template>
<script>
import pfEmptyTable from '@/components/pfEmptyTable'

const components = {
  pfEmptyTable
}

const props = {
  id: {
    type: String
  }
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useStore } from '../_composables/useCollection'
import { dhcpOption82Fields } from '../_config/'

const setup = (props, context) => {

  const { id } = toRefs(props)
  const { root: { $store } = {} } = context

  const node = computed(() => $store.state.$_nodes.nodes[id.value])

  const dhcpOption82SortBy = ref('created_at')
  const dhcpOption82SortDesc = ref(true)

  const {
    isLoading
  } = useStore(props, context)  

  return {
    dhcpOption82Fields,
    
    dhcpOption82SortBy,
    dhcpOption82SortDesc,
    isLoading,
    node
  }
}
// @vue/component
export default {
  name: 'tab-dhcp-option82-logs',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>