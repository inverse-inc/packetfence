<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Provisioning') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#provision" />
          </h4>
        </b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-dropdown :text="$t('New Provisioner')" variant="outline-primary">
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'accept' } }">Accept</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'android' } }">Android</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'deny' } }">Deny</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'dpsk' } }">dpsk</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'ibm' } }">IBM</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'jamf' } }">Jamf</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'mobileconfig' } }">Apple Devices</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'mobileiron' } }">Mobileiron</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'opswat' } }">OPSWAT</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'sentinelone' } }">SentinelOne</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'sepm' } }">Symantec Endpoint Protection Manager (SEPM)</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'symantec' } }">Symantec App Center</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'windows' } }">Windows</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'intune' } }">Microsoft Intune</b-dropdown-item>
          <b-dropdown-item :to="{ name: 'newProvisioning', params: { provisioningType: 'servicenow' } }">Service Now</b-dropdown-item>
        </b-dropdown>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No Provisioners found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
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
import {
  pfConfigurationProvisioningListConfig as config
} from '@/globals/configuration/pfConfigurationProvisionings'

export default {
  name: 'provisionings-list',
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
      this.$router.push({ name: 'cloneProvisioning', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteProvisioning`, item.id).then(response => {
        this.$router.go() // reload
      })
    }
  }
}
</script>
