<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Provisioning') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#provision" />
          </h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-dropdown :text="$t('New Provisioner')" variant="outline-primary">
          <template v-for="({ text, value }) in provisioningTypeOptions">
            <b-dropdown-item :key="value"
              :to="{ name: 'newProvisioning', params: { provisioningType: value } }">{{ text }}</b-dropdown-item>
          </template>
        </b-dropdown>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No Provisioners found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Provisioner?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/provisioning'
import { provisioningTypeOptions } from '../provisioners/config'

export default {
  name: 'provisionings-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this),
      provisioningTypeOptions
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_provisionings/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneProvisioning', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_provisionings/deleteProvisioning', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    }
  }
}
</script>
