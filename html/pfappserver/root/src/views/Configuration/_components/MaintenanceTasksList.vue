<template>
  <pf-config-list
    ref="pfConfigList"
    :config="config"
  >
    <template v-slot:pageHeader>
      <b-card-header>
        <h4 class="mb-3" v-t="'Maintenance Tasks'"></h4>
        <p class="mb-0" v-t="'Enabling or disabling a task as well as modifying its interval requires a restart of pfcron to be fully effective.'"></p>
      </b-card-header>
    </template>
    <template v-slot:buttonAdd>
      <pf-button-service service="pfcron" class="mr-1" restart start stop :disabled="isLoading"></pf-button-service>
    </template>
    <template v-slot:emptySearch="state">
      <pf-empty-table :isLoading="state.isLoading">{{ $t('No maintenance tasks found') }}</pf-empty-table>
    </template>
    <template v-slot:cell(status)="item">
      <toggle-status :value="item.status" :item="item" :disabled="isLoading" /> 
    </template>
    <template v-slot:cell(interval)="{ interval }">
      <template v-if="interval"><!-- TODO: Temporary workaround for issue #4902 -->
        {{ interval.interval }}{{ interval.unit }}
      </template>
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/maintenanceTask'
import { ToggleStatus } from '@/views/Configuration/maintenanceTasks/_components/'

export default {
  name: 'maintenance-tasks-list',
  components: {
    pfButtonService,
    pfConfigList,
    pfEmptyTable,
    ToggleStatus 
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_maintenance_tasks/isLoading']
    }
  }
}
</script>
