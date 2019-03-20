<template>
  <pf-config-list
    :config="config"
  >
    <template slot="pageHeader">
      <h4 v-t="'Maintenance Tasks'"></h4>
      <p v-t="'Enabling or disabling a task as well as modifying its interval requires a restart of pfmon to be fully effective.'"></p>
    </template>
    <template slot="buttonAdd">
      <pf-button-service service="pfmon" class="mr-1" restart start stop></pf-button-service>
    </template>
    <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No maintenance tasks found') }}</pf-empty-table>
    </template>
    <template slot="status" slot-scope="data">
      <icon name="circle" :class="{ 'text-success': data.status === 'enabled', 'text-danger': data.status === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(data.status)"></icon>
    </template>
    <template slot="interval" slot-scope="item">
      {{ item.interval.interval }}{{ item.interval.unit }}
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationMaintenanceTasksListConfig as config
} from '@/globals/configuration/pfConfigurationMaintenanceTasks'

export default {
  name: 'MaintenanceTasksList',
  components: {
    pfButtonDelete,
    pfButtonService,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this)
    }
  }
}
</script>
