<template>
  <b-card no-body class="mt-3" ref="networkGraphContainer">
    <b-card-header>
      <div class="float-right"><pf-form-toggle v-model="advancedMode">{{ $t('Advanced') }}</pf-form-toggle></div>
      <h4 class="mb-0" v-t="'Network'"></h4>
    </b-card-header>
    <div class="card-body">
      <transition name="fade" mode="out-in">
        <!-- Advanced Search Mode -->
        <div v-if="advancedMode">
          <b-form inline @submit.prevent="onSubmit" @reset.prevent="onReset">
            <pf-search-boolean :model="advancedCondition" :fields="fields" :advancedMode="advancedMode"/>
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
        </div>
        <!-- Quick Search Mode -->
        <b-form @submit.prevent="onSubmit" @reset.prevent="onReset" v-else>
          <div class="input-group">
            <div class="input-group-prepend">
              <div class="input-group-text"><icon name="search"></icon></div>
            </div>
            <b-form-input v-model="quickCondition" type="text" :placeholder="$t('Search by...')"></b-form-input>
            <b-button class="ml-1" type="reset" variant="secondary" :disabled="!quickCondition">{{ $t('Clear') }}</b-button>
            <!--
            <b-button class="ml-1" type="submit" variant="primary" :disabled="!quickCondition">{{ $t('Search') }}</b-button>
            -->
            <b-button-group class="ml-1" :disabled="!quickCondition">
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
          </div>
        </b-form>
      </transition>

      <!-- Saved Search Modal -->
      <b-modal v-model="showSaveSearchModal" size="sm" centered id="saveSearchModal" :title="$t('Save Search')" @shown="focusSaveSearchInput">
        <b-form-input ref="saveSearchInput" v-model="saveSearchString" type="text"
          :placeholder="$t('Enter a unique name')" @keyup="keyUpSaveSearchInput"/>
        <div slot="modal-footer">
          <b-button variant="secondary" class="mr-1" @click="showSaveSearchModal=false">{{ $t('Cancel') }}</b-button>
          <b-button variant="primary" @click="saveSearch">{{ $t('Save') }}</b-button>
        </div>
      </b-modal>

      <div class="mt-3">

        <b-row align-h="between" align-v="center">
          <b-col cols="auto" class="mr-auto">

            <b-input-group class="mb-0" size="sm">
              <b-input-group-prepend is-text>
                <pf-form-range-toggle class="inline mt-n2" v-model="liveMode" :disabled="isLoading || !liveModeAllowed"></pf-form-range-toggle>
              </b-input-group-prepend>
              <b-dropdown variant="light" :text="$t('Live View')" :disabled="isLoading || !liveModeAllowed">
                <b-dropdown-item v-for="timeout in [5000, 10000, 15000, 30000, 60000, 120000, 300000]" :key="timeout"
                  :active="liveMode === true && liveModeIntervalMs === timeout"
                  @click="liveMode = true; liveModeIntervalMs = timeout"
                >{{ $t('{duration} seconds', { duration: timeout / 1E3 }) }}</b-dropdown-item>
              </b-dropdown>
            </b-input-group>
          </b-col>
          <b-col cols="auto">
            <b-container fluid>
              <b-row align-v="center">
                <b-form inline class="mb-0">
                  <b-button-group class="ml-3" size="sm">
                    <b-button disabled variant="outline-primary"><icon name="window-maximize" class="mx-1"/></b-button>
                    <b-button @click="dimensions.fit = 'min'" :variant="(dimensions.fit === 'min') ? 'primary' : 'outline-primary'" :disabled="isLoading">{{ $t('Minimize') }}</b-button>
                    <b-button @click="dimensions.fit = 'max'" :variant="(dimensions.fit === 'max') ? 'primary' : 'outline-primary'" :disabled="isLoading">{{ $t('Maximize') }}</b-button>
                  </b-button-group>
                </b-form>
                <b-form inline class="mb-0">
                  <b-button-group class="ml-3" size="sm">
                    <b-button disabled variant="outline-primary"><icon name="project-diagram" class="mx-1"/></b-button>
                    <b-button v-for="layout in layouts" :key="layout" @click="options.layout = layout" :variant="(options.layout === layout) ? 'primary' : 'outline-primary'" :disabled="isLoading">{{ layout }}</b-button>
                  </b-button-group>
                </b-form>
                <b-form inline class="mb-0">
                  <b-button-group class="ml-3" size="sm">
                    <b-button disabled variant="outline-primary"><icon name="palette" class="mx-1"/></b-button>
                    <b-button v-for="palette in Object.keys(palettes)" :key="palette" @click="options.palette = palette" :variant="(options.palette === palette) ? 'primary' : 'outline-primary'" :disabled="isLoading">{{ palette }}</b-button>
                  </b-button-group>
                </b-form>
                <b-form inline class="mb-0">
                  <b-form-select class="ml-3" size="sm" v-model="limit" :options="[25,50,100,200,500,1000]" :disabled="isLoading" @input="onLimit"/>
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
          :palettes="palettes"
          :disabled="isLoading"
          :is-loading="isLoading"
          @layouts="layouts = $event"
        />

      </div>
    </div>
  </b-card>
</template>

<script>
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormToggle from '@/components/pfFormToggle'
import pfNetworkGraph from '@/components/pfNetworkGraph'
import pfSearchBoolean from '@/components/pfSearchBoolean'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import apiCall from '@/utils/api'

const api = {
  networkGraph: body => {
    return apiCall.post('nodes/network_graph', body).then(response => {
      return response.data
    }).catch((err) => {
      throw err
    })
  }
}

export default {
  name: 'network',
  components: {
    pfFormRangeToggle,
    pfFormToggle,
    pfNetworkGraph,
    pfSearchBoolean
  },
  props: {
    query: {
      type: String,
      default: null
    }
  },
  data () {
    return {
      dimensions: {
        height: 0,
        width: 0,
        fit: 'min'
      },
      nodes: [],
      links: [],
      options: {
        layout: 'radial',
        legendPosition: 'top-right',
        palette: 'status', // autoreg|status|online|voip
        miniMapHeight: undefined,
        miniMapWidth: 200,
        miniMapPosition: 'bottom-left',
        minZoom: 0,
        maxZoom: 4,
        mouseWheelZoom: true,
        padding: 25,
        sort: 'last_seen',
        order: 'DESC'
      },
      layouts: [], // available layouts
      palettes: {
        autoreg: {
          yes: 'green',
          no: 'red'
        },
        online: {
          on: 'green',
          off: 'red',
          unknown: 'yellow'
        },
        voip: {
          yes: 'green',
          no: 'red'
        },
        status: {
          reg: 'green',
          unreg: 'red'
        }
      },
      saveSearchNamespace: 'network',
      saveSearchString: null,
      showSaveSearchModal: false,
      quickCondition: null,
      advancedCondition: null,
      advancedMode: false,
      defaultCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [{
            field: 'last_seen',
            op: 'greater_than_equals',
            value: '1970-01-01 00:00:00'
          }]
        }]
      },
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
      ],
      isLoading: false,
      liveMode: false,
      liveModeAllowed: false,
      liveModeInterval: false,
      liveModeIntervalMs: 30000
    }
  },
  computed: {
    condition () {
      const { advancedMode = false, advancedCondition = null, quickCondition = null } = this
      if (advancedMode) {
        return advancedCondition
      } else if (quickCondition) {
        return this.buildCondition(quickCondition)
      }
      return null
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
      this.$set(this.dimensions, 'width', width)
      if (this.dimensions.fit === 'max') {
        this.$set(this.dimensions, 'height', width)
      } else {
        // get height of window document
        const documentHeight = Math.max(document.documentElement.clientHeight, window.innerHeight || 0)
        const { $refs: { networkGraph: { $el = {} } = {} } = {} } = this
        const { top: networkGraphTop } = $el.getBoundingClientRect()
        const padding = 20 + 16 /* padding = 20, margin = 16 */
        const height = documentHeight - networkGraphTop - padding
        this.$set(this.dimensions, 'height', height)
        if (height < 0) {
          setTimeout(this.setDimensions, 100) // try again when DOM is ready
        }
      }
    },
    onSubmit (liveMode = false) {
      if (!liveMode) this.isLoading = true
      const { condition: query = null, limit, palettes } = this
      if (query) {
        const request = {
          cursor: 0,
          limit,
          fields: [...(new Set([ // unique set
            ...['mac', 'last_seen'].map(key => `node.${key}`), // include `node.mac` and `node.last_seen`
            ...Object.keys(palettes).map(key => `node.${key}`), // include node fields for palettes
            ...['description', 'type'].map(key => `switch.${key}`), // include `switch` data
            ...['connection_type', 'port', 'realm', 'role', 'ssid', 'switch_mac', 'vlan'].map(key => `locationlog.${key}`) // include `locationlog` data
          ]))],
          sort: [`${this.options.sort} ${this.options.order}`],
          query
        }
        const start = performance.now()
        api.networkGraph(request).then(response => {
          let { network_graph: { nodes = [], links = [] } = {} } = response
          if (nodes.length === 1 && nodes.filter(n => n.type !== 'packetfence').length === 0) { // ignore single `packetfence` node
            this.nodes = []
          } else {
            this.nodes = nodes
          }
          this.links = links
          this.liveModeAllowed = true
        }).catch(() => {
          this.nodes = []
          this.links = []
          this.liveMode = false
          this.liveModeAllowed = false
        }).then(() => { // finally
          if (!liveMode) this.isLoading = false
          this.liveModeIntervalMs = Math.max(this.liveModeIntervalMs, performance.now() - start) // adjust polling interval
        })
      }
    },
    onReset () {
      const { advancedMode } = this
      if (advancedMode) {
        this.advancedCondition = this.defaultCondition
      } else {
        this.quickCondition = null
      }
      this.nodes = []
      this.links = []
    },
    onLimit () {
      if (this.condition) {
        this.onSubmit()
      }
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
  watch: {
    advancedMode: {
      handler: function (a, b) {
        this.setDimensions()
      }
    },
    'dimensions.fit': {
      handler: function (a, b) {
        this.setDimensions()
      }
    },
    windowSize: {
      handler: function (a, b) {
        if (a.clientWidth !== b.clientWidth || a.clientHeight !== b.clientHeight) {
          this.setDimensions()
        }
      },
      deep: true
    },
    query: {
      handler: function (a, b) {
        if (a) {
          // Import search parameters from URL query
          this.advancedCondition = JSON.parse(a)
          this.advancedMode = true
          this.onSubmit()
        }
      },
      deep: true,
      immediate: true
    },
    condition: {
      handler: function (a, b) {
        this.liveMode = false // disable live mode
        this.liveModeAllowed = false // disallow live mode
        if (JSON.stringify(a) !== this.query) {
          this.$router.push({ query: null }) // clear URL query variable
        }
      },
      deep: true
    },
    liveMode: {
      handler: function (a, b) {
        if (this.liveModeInterval) {
          clearInterval(this.liveModeInterval)
        }
        if (a) {
          this.liveModeInterval = setInterval(() => {
            this.onSubmit(true)
          }, this.liveModeIntervalMs)
        }
      }
    }
  },
  mounted () {
    this.setDimensions()
    this.advancedCondition = this.defaultCondition
  },
  beforeDestroy () {
    if (this.liveModeInterval) {
      clearTimeout(this.liveModeInterval)
    }
  }
}
</script>
