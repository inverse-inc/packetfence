<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Floating Devices'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newFloatingDevice' }">{{ $t('Add Floating Device') }}</b-button>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No devices found') }}</pf-empty-table>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationFloatingDevicesListColumns as columns,
  pfConfigurationFloatingDevicesListFields as fields
} from '@/globals/pfConfigurationFloatingDevices'

export default {
  name: 'FloatingDevicesList',
  components: {
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: {
        columns: columns,
        fields: fields,
        rowClickRoute (item, index) {
          return { name: 'floating_device', params: { id: item.id } }
        },
        searchPlaceholder: this.$i18n.t('Search by MAC or IP address'),
        searchableOptions: {
          searchApiEndpoint: 'config/floating_devices',
          defaultSortKeys: ['id'],
          defaultSearchCondition: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: null },
                { field: 'ip', op: 'contains', value: null }
              ]
            }]
          },
          defaultRoute: { name: 'configuration/floating_devices' }
        },
        searchableQuickCondition: (quickCondition) => {
          return {
            op: 'and',
            values: [
              {
                op: 'or',
                values: [
                  { field: 'id', op: 'contains', value: quickCondition },
                  { field: 'ip', op: 'contains', value: quickCondition }
                ]
              }
            ]
          }
        }
      }
    }
  }
}
</script>
