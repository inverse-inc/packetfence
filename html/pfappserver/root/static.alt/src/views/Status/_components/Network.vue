<template>
  <b-card no-body class="mt-3">
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Network'"></h4>
    </b-card-header>
    <div class="card-body">

      <transition name="fade" mode="out-in">
        <!-- Advanced Search Mode -->
        <div v-if="advancedMode">
          <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset">
            <pf-search-boolean :model="condition" :fields="fields" :advancedMode="advancedMode"/>
            <b-container fluid class="text-right mt-3 px-0">
              <b-button class="mr-1" type="reset" variant="secondary">{{ $t('Clear') }}</b-button>
              <b-button-group>
                <b-button type="submit" variant="primary">{{ $t('Search') }}</b-button>
                <b-dropdown variant="primary" right>
                  <b-dropdown-header>{{ $t('Saved Searches') }}</b-dropdown-header>
                  <b-dropdown-item @click="showSaveSearchModal=true">
                    <icon class="position-absolute mt-1" name="save"></icon>
                    <span class="ml-4">{{ $t('Save Search') }}</span>
                  </b-dropdown-item>
                  <template v-if="savedSearches.length > 0">
                    <b-dropdown-item v-for="search in savedSearches" :key="search.name" :to="search.route">
                      <icon class="position-absolute mt-1" name="trash-alt" @click.native.stop.prevent="deleteSavedSearch(search)"></icon>
                      <span class="ml-4">{{ search.name }}</span>
                    </b-dropdown-item>
                  </template>
                </b-dropdown>
              </b-button-group>
            </b-container>
          </b-form>
          <b-modal v-model="showSaveSearchModal" size="sm" centered id="saveSearchModal" :title="$t('Save Search')" @shown="focusSaveSearchInput">
            <b-form-input ref="saveSearchInput" v-model="saveSearchString" type="text"
              :placeholder="$t('Enter a unique name')" @keyup="keyUpSaveSearchInput"/>
            <div slot="modal-footer">
              <b-button variant="secondary" class="mr-1" @click="showSaveSearchModal=false">{{ $t('Cancel') }}</b-button>
              <b-button variant="primary" @click="saveSearch">{{ $t('Save') }}</b-button>
            </div>
          </b-modal>
        </div>
        <!-- Quick Search Mode -->
        <b-form @submit.prevent="onSubmit" @reset.prevent="onReset" v-else>
          <div class="input-group">
            <div class="input-group-prepend">
              <div class="input-group-text"><icon name="search"></icon></div>
            </div>
            <b-form-input v-model="quickCondition" type="text" :placeholder="$t('Search by...')"></b-form-input>
            <b-button class="ml-1" type="reset" variant="secondary">{{ $t('Clear') }}</b-button>
            <b-button class="ml-1" type="submit" variant="primary">{{ $t('Search') }}</b-button>
          </div>
        </b-form>
      </transition>

      <div class="mt-3">

        <b-row align-h="between" align-v="center">
          <b-col cols="auto" class="mr-auto">
...
          </b-col>
          <b-col cols="auto">
            <b-container fluid>
              <b-row align-v="center">
                <b-form inline class="mb-0">
                  <b-form-select class="mb-3 mr-3" size="sm" v-model="options.palette" :options="palettes" :disabled="isLoading"/>
                </b-form>
                <b-form inline class="mb-0">
                  <b-form-select class="mb-3 mr-3" size="sm" v-model="limit" :options="[25,50,100,200,500,1000]" :disabled="isLoading" @input="onSubmit"/>
                </b-form>
              </b-row>
            </b-container>
          </b-col>
        </b-row>
        <pf-network-graph ref="networkGraph"
          :dimensions="dimensions"
          :nodes="nodes"
          :links="links"
          :options="options"
          :is-loading="isLoading"
        />
      </div>
    </div>
  </b-card>
</template>

<script>
import pfFormToggle from '@/components/pfFormToggle'
import pfNetworkGraph from '@/components/pfNetworkGraph'
import pfSearchBoolean from '@/components/pfSearchBoolean'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import apiCall from '@/utils/api'

const api = {
  networkGraph: body => {
    return apiCall.post('nodes/network_graph', body).then(response => {
      return response.data
    })
  }
}

export default {
  name: 'network',
  components: {
    pfFormToggle,
    pfNetworkGraph,
    pfSearchBoolean
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
      dimensions: {
        height: Math.max(document.documentElement.clientHeight, window.innerHeight || 0) - 40,
        width: 0
      },
      nodes: [],
      links: [],
      options: {
        layout: 'radial',
        palette: 'status', // autoreg|status|online|voip
        miniMapHeight: undefined,
        miniMapWidth: 200,
        miniMapPosition: 'bottom-left',
        minZoom: 0,
        maxZoom: 4,
        mouseWheelZoom: true,
        padding: 25,
        tooltipDistance: 50
      },
      palettes: ['autoreg', 'status', 'online', 'voip'], // available palettes
      pollingIntervalMs: 60000,
      pollingInterval: false,
      advancedMode: false,
      saveSearchNamespace: 'network',
      saveSearchString: null,
      showSaveSearchModal: false,
      quickCondition: null,
      condition: null,
      limit: 100,
      /**
       *  Fields on which a search can be defined.
       *  The names must match the database schema.
       *  The keys must conform to the format of the b-form-select's options property.
       */
      fields: [
        {
          value: 'tenant_id',
          text: this.$i18n.t('Tenant'),
          types: [conditionType.INTEGER]
        },
        {
          value: 'status',
          text: this.$i18n.t('Status'),
          types: [conditionType.NODE_STATUS],
          icon: 'power-off'
        },
        {
          value: 'mac',
          text: this.$i18n.t('MAC Address'),
          types: [conditionType.SUBSTRING],
          icon: 'id-card'
        },
        {
          value: 'bypass_role_id',
          text: this.$i18n.t('Bypass Role'),
          types: [conditionType.ROLE, conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'bypass_vlan',
          text: this.$i18n.t('Bypass VLAN'),
          types: [conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'computername',
          text: this.$i18n.t('Computer Name'),
          types: [conditionType.SUBSTRING],
          icon: 'desktop'
        },
        {
          value: 'locationlog.connection_type',
          text: this.$i18n.t('Connection Type'),
          types: [conditionType.CONNECTION_TYPE],
          icon: 'plug'
        },
        {
          value: 'detect_date',
          text: this.$i18n.t('Detected Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'regdate',
          text: this.$i18n.t('Registered Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'unregdate',
          text: this.$i18n.t('Unregistered Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'last_arp',
          text: this.$i18n.t('Last ARP Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'last_dhcp',
          text: this.$i18n.t('Last DHCP Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'last_seen',
          text: this.$i18n.t('Last seen Date'),
          types: [conditionType.DATETIME],
          icon: 'calendar-alt'
        },
        {
          value: 'device_class',
          text: this.$i18n.t('Device Class'),
          types: [conditionType.SUBSTRING],
          icon: 'barcode'
        },
        {
          value: 'device_manufacturer',
          text: this.$i18n.t('Device Manufacturer'),
          types: [conditionType.SUBSTRING],
          icon: 'barcode'
        },
        {
          value: 'device_type',
          text: this.$i18n.t('Device Type'),
          types: [conditionType.SUBSTRING],
          icon: 'barcode'
        },
        {
          value: 'device_version',
          text: this.$i18n.t('Device Version'),
          types: [conditionType.SUBSTRING],
          icon: 'barcode'
        },
        {
          value: 'ip4log.ip',
          text: this.$i18n.t('IPv4 Address'),
          types: [conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        /*
        {
          value: 'ip6log.ip',
          text: this.$i18n.t('IPv6 Address'),
          types: [conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        */
        {
          value: 'machine_account',
          text: this.$i18n.t('Machine Account'),
          types: [conditionType.SUBSTRING],
          icon: 'desktop'
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          types: [conditionType.SUBSTRING],
          icon: 'notes-medical'
        },
        {
          value: 'online',
          text: this.$i18n.t('Online Status'),
          types: [conditionType.ONLINE],
          icon: 'power-off'
        },
        {
          value: 'pid',
          text: this.$i18n.t('Owner'),
          types: [conditionType.SUBSTRING],
          icon: 'user'
        },
        {
          value: 'category_id',
          text: this.$i18n.t('Role'),
          types: [conditionType.ROLE, conditionType.SUBSTRING],
          icon: 'project-diagram'
        },
        {
          value: 'locationlog.switch',
          text: this.$i18n.t('Source Switch Identifier'),
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.switch_ip',
          text: this.$i18n.t('Source Switch IP'),
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.switch_mac',
          text: this.$i18n.t('Source Switch MAC'),
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.port',
          text: this.$i18n.t('Source Switch Port'),
          types: [conditionType.INTEGER],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.ifDesc',
          text: this.$i18n.t('Source Switch Port Description'),
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.ifDesc',
          text: this.$i18n.t('Source Switch Description'),
          types: [conditionType.SUBSTRING],
          icon: 'sitemap'
        },
        {
          value: 'locationlog.ssid',
          text: this.$i18n.t('SSID'),
          types: [conditionType.SUBSTRING],
          icon: 'wifi'
        },
        {
          value: 'user_agent',
          text: this.$i18n.t('User Agent'),
          types: [conditionType.SUBSTRING],
          icon: 'user-secret'
        },
        /* TODO - #3400, #4166
        {
          value: 'security_event.open_security_event_id',
          text: this.$i18n.t('Security Event Open'),
          types: [conditionType.SECURITY_EVENT],
          icon: 'exclamation-triangle'
        },
        {
          value: 'security_event.open_count',
          text: this.$i18n.t('Security Event Open Count [Issue #3400]'),
          types: [conditionType.INTEGER],
          icon: 'exclamation-triangle'
        },
        {
          value: 'security_event.close_security_event_id',
          text: this.$i18n.t('Security Event Closed'),
          types: [conditionType.SECURITY_EVENT],
          icon: 'exclamation-circle'
        },
        {
          value: 'security_event.close_count',
          text: this.$i18n.t('Security Event Close Count [Issue #3400]'),
          types: [conditionType.INTEGER],
          icon: 'exclamation-circle'
        },
        */
        {
          value: 'voip',
          text: this.$i18n.t('VoIP'),
          types: [conditionType.YESNO],
          icon: 'phone'
        },
        {
          value: 'autoreg',
          text: this.$i18n.t('Auto Registration'),
          types: [conditionType.YESNO],
          icon: 'magic'
        },
        {
          value: 'bandwidth_balance',
          text: this.$i18n.t('Bandwidth Balance'),
          types: [conditionType.PREFIXMULTIPLE],
          icon: 'balance-scale'
        }
      ]
    }
  },
  computed: {
    condition () {
      return this.defaultCondition
    },
    isLoading () {
      return this.$store.state[this.storeName].isLoading
    },
    windowSize () {
      return this.$store.getters['events/windowSize']
    },
    savedSearches () {
      return this.$store.getters['saveSearch/cache'][this.saveSearchNamespace] || []
    }
  },
  methods: {
    setDimensions () {
      // get width of svg container
      const { $refs: { networkGraph: { $el: { offsetWidth: width = 0 } = {} } = {} } = {} } = this
      // this.$set(this.dimensions, 'height', width)
      this.$set(this.dimensions, 'width', width)
    },
    onSubmit () {
      const { limit, condition: query } = this
      const request = {
        cursor: 0,
        limit,
        fields: [...(new Set([ // unique set
          ...['mac'], // always include mac
          ...this.palettes, // always include fields for palette colors
          ...this.fields.map(f => f.value)
        ]))],
        sort: ['last_seen DESC'],
        query: {
          op: 'and',
          values: [{
            op: 'or',
            values: [{
              field: 'last_seen',
              op: 'greater_than_equals',
              value: '2000-01-01 00:00:00'
            }]
          }]
        }
      }

      // this.$set(this, 'nodes', this.nodes.filter(n => n.type === 'packetfence'))
      // this.$set(this, 'links', [])

      api.networkGraph(request).then(response => {
        let { network_graph: { nodes, links } = {} } = response
        /*
        // improve layout by sorting nodes by source id
        nodes = nodes.sort((a, b) => {
          const { source: aSourceId = null } = links.find(l => l.target === a.id) || {}
          const { source: bSourceId = null } = links.find(l => l.target === b.id) || {}
          switch (true) {
            case aSourceId.localeCompare(bSourceId) === -1:
              return -1
            case aSourceId.localeCompare(bSourceId) === 1:
              return 1
            case a.id.localeCompare(b.id) === -1:
              return -1
            case a.id.localeCompare(b.id) === 1:
              return 1
            default:
              return 0
          }
        })
        links = links.sort((a, b) => {
          return a.source.localeCompare(b.source)
        })
        */


        this.$set(this, 'nodes', nodes)
        this.$set(this, 'links', links)
      })


    },
    onReset () {
console.log('onReset')
    },
    focusSaveSearchInput () {
      this.$refs.saveSearchInput.focus()
    },
    keyUpSaveSearchInput (event) {
      switch (event.keyCode) {
        case 13: // [ENTER] submits
          if (this.saveSearchString.length > 0) this.saveSearch()
          break
      }
    },
    saveSearch () {
      const { $route: { path, params } = {} } = this
      this.$store.dispatch('saveSearch/set', {
        namespace: this.saveSearchNamespace,
        search: {
          name: this.saveSearchString,
          route: {
            path,
            params,
            query: {
              query: JSON.stringify(this.condition)
            }
          }
        }
      }).then(response => {
        this.saveSearchString = ''
        this.showSaveSearchModal = false
      })
    },
    deleteSavedSearch (search) {
      this.$store.dispatch('saveSearch/remove', { namespace: this.saveSearchNamespace, search: { name: search.name } })
    },
    buildCondition (value) {
      return {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { 'field': 'mac', 'op': 'contains', value },
            { 'field': 'computername', 'op': 'contains', value },
            { 'field': 'device_class', 'op': 'contains', value },
            { 'field': 'device_manufacturer', 'op': 'contains', value },
            { 'field': 'device_type', 'op': 'contains', value },
            { 'field': 'device_version', 'op': 'contains', value },
            { 'field': 'ip4log.ip', 'op': 'contains', value },
            { 'field': 'locationlog.ssid', 'op': 'contains', value },
            { 'field': 'machine_account', 'op': 'contains', value },
            { 'field': 'pid', 'op': 'contains', value },
            { 'field': 'user_agent', 'op': 'contains', value }
          ]
        }]
      }
    }
  },
  mounted () {
    this.setDimensions()
  },
  watch: {
    windowSize: {
      handler: function (a, b) {
        if (a.clientWidth !== b.clientWidth || a.clientHeight !== b.clientHeight) {
          this.setDimensions()
        }
      },
      deep: true
    },
    quickCondition: {
      handler: function (a, b) {
        this.condition = this.buildCondition(a)
      },
      immediate: true
    }
  }
}
</script>
