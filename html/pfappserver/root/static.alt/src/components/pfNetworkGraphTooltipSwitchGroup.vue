<template>
  <b-card no-body class="pf-network-graph-tooltip-switch-group">
    <b-card-header>
      <h5 class="mb-0 text-nowrap">{{ $t('Switch Group') }}</h5>
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
      <b-container class="container px-0" v-else-if="!isError">
        <b-row v-if="switchGroup.description">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Decription'"></p>
            <p class="mb-2" v-text="switchGroup.description"></p>
          </b-col>
        </b-row>
        <b-row v-if="switchGroup.type">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Type'"></p>
            <p class="mb-2" v-text="switchGroup.type"></p>
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
  name: 'pf-network-graph-tooltip-switch-group',
  components: {
    pfFormRow
  },
  props: {
    id: {
      type: String
    },
    properties: {
      type: Object,
      default: () => { return {} }
    }
  },
  data () {
    return {
      switchGroup: false,
      isLoading: false,
      isError: false
    }
  },
  methods: {
    init () {
      this.isLoading = true
      apiCall.getQuiet(`config/switch_group/${this.id}`).then(response => {
        this.switchGroup = response.data.item
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

.pf-network-graph-tooltip-switch-group {
  .container {
    animation: expandheight 300ms;
    overflow-x: initial;
  }
}
</style>
