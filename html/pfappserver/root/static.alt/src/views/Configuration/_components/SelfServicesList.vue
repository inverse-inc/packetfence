<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Device Registration') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_devices_registration" />
          </h4>
        </b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newSelfService' }">{{ $t('New Device Registration') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No device registrations found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Device Registration?')" @on-delete="remove(item)" reverse/>
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
import {
  pfConfigurationSelfServicesListConfig as config
} from '@/globals/configuration/pfConfigurationSelfServices'

export default {
  name: 'self-services-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      config: config(this)
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneSelfService', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteSelfService`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
