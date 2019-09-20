<template>
  <b-card no-body class="pf-network-graph-tooltip-node">
    <b-card-header>
      <h5 class="mb-0 text-nowrap">{{ $t('Node') }}</h5>
      <p class="mb-0"><mac>{{ id }}</mac></p>
    </b-card-header>
    <div class="card-body" v-if="isLoading || !isError">
      <b-container class="my-3 px-0" v-if="isLoading">
        <b-row class="justify-content-md-center text-secondary">
          <b-col cols="12" md="auto" class="w-100 text-center">
            <icon name="circle-notch" scale="2" spin></icon>
          </b-col>
        </b-row>
      </b-container>
      <b-container fluid class="container px-0" v-else-if="!isError">
        <b-row v-if="node.device_class">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Class'"></p>
            <p class="mb-2" v-text="node.device_class"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_manufacturer">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Manufacturer'"></p>
            <p class="mb-2" v-text="node.device_manufacturer"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_type">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Type'"></p>
            <p class="mb-2" v-text="node.device_type"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_version">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Version'"></p>
            <p class="mb-2" v-text="node.device_version"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.computername">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Computer Name'"></p>
            <p class="mb-2" v-text="node.computername"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.machine_account">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Machine Account'"></p>
            <p class="mb-2" v-text="node.machine_account"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.pid">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Owner'"></p>
            <p class="mb-2" v-text="node.pid"></p>
          </b-col>
        </b-row>
      </b-container>
    </div>
  </b-card>
</template>

<script>
import apiCall from '@/utils/api'
import pfFormRow from '@/components/pfFormRow'

export default {
  name: 'pf-network-graph-tooltip-node',
  components: {
    pfFormRow
  },
  props: {
    id: {
      type: String
    }
  },
  data () {
    return {
      node: false,
      isLoading: false,
      isError: false
    }
  },
  methods: {
    init () {
      this.isLoading = true
      apiCall.getQuiet(`node/${this.id}`).then(response => {
        this.node = response.data.item
        this.isLoading = false
      }).catch(err => {
        this.isError = err
        this.isLoading = false
      })
    }
  },
  mounted () {
    this.init()
  },
  watch: {
    id: {
      handler: function (a, b) {
        this.init()
      }
    }
  }
}
</script>

<style lang="scss">
@keyframes expandheight {
  from { max-height: 0px; overflow-y: hidden; }
  to   { max-height: 500px; overflow-y: initial; }
}

.pf-network-graph-tooltip-node {
  .container {
    animation: expandheight 300ms;
    overflow-x: initial;
  }
}
</style>
