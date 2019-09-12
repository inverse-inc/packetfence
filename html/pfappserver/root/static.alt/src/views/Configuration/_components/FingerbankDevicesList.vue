<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header>
          <b-row class="align-items-center px-0" no-gutters>
            <b-col cols="auto" class="mr-auto">
              <h4 class="d-inline mb-0" v-t="'Devices'"></h4>
            </b-col>
            <b-col cols="auto" align="right" class="flex-grow-0">
              <b-button-group>
                <b-button v-t="'All'" :variant="(scope === 'all') ? 'primary' : 'outline-secondary'" @click="changeScope('all')"></b-button>
                <b-button v-t="'Local'" :variant="(scope === 'local') ? 'primary' : 'outline-secondary'" @click="changeScope('local')"></b-button>
                <b-button v-t="'Upstream'" :variant="(scope === 'upstream') ? 'primary' : 'outline-secondary'" @click="changeScope('upstream')"></b-button>
              </b-button-group>
            </b-col>
          </b-row>
        </b-card-header>
      </template>
      <template slot="tableHeader" v-if="parentTree.length > 0">
        <b-row class="mb-3">
          <b-col cols="auto">
            <b-button variant="link" class="px-0 mr-2 text-secondary" :to="{ name: 'fingerbankDevices', params: { scope: scope } }">
              <icon name="times" variant="primary"></icon>
            </b-button>
            <b-button v-for="(parent, index) in parentTreeReverse" :key="parent.id" variant="link" class="px-0 mr-2 text-primary" :disabled="index === parentTree.length - 1" :to="{ name: 'fingerbankDevicesByParentId', params: { parentId: parent.id, scope: scope } }">
              <icon v-if="index > 0" name="caret-right" variant="text-secondary" class="mr-1"></icon>
              {{ parent.name }}
            </b-button>
          <b-col>
        </b-row>
      </template>
      <template slot="buttonAdd" v-if="scope === 'local'">
        <b-button variant="outline-primary" :to="{ name: 'newDevice', params: { scope: 'local' } }">{{ $t('New Device') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No devices found') }}</pf-empty-table>
      </template>
      <template slot="id" slot-scope="data">
        <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="setParentId(data.id)">
          <span class="text-nowrap align-items-center ml-2">
            {{ data.id }} <icon name="plus-circle" class="ml-2"></icon>
          </span>
        </b-button>
      </template>
      <template slot="approved" slot-scope="data">
        <icon name="circle" :class="{ 'text-success': data.approved === 1, 'text-danger': data.approved === 0 }"></icon>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable && scope === 'local'" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Device?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationFingerbankDevicesListConfig as config
} from '@/globals/configuration/pfConfigurationFingerbank'

export default {
  name: 'fingerbank-devices-list',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    parentId: {
      type: Number,
      default: null
    },
    scope: {
      type: String,
      default: 'all',
      required: false
    }
  },
  data () {
    return {
      config: config(this),
      parentTree: []
    }
  },
  computed: {
    parentTreeReverse () { // parentTree.reverse() issue within template, mutates Array immediately and causes infinite-loop w/ reactivity updates.
      return JSON.parse(JSON.stringify(this.parentTree)).reverse()
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneFingerbankDevice', params: { scope: 'local', id: item.id } })
    },
    remove (item) {
      this.$store.dispatch(`${this.storeName}/deleteDevice`, item.id).then(response => {
        this.$router.go() // reload
      })
    },
    setParentId (id) {
      this.$router.push({ name: 'fingerbankDevicesByParentId', params: { parentId: id } })
    },
    clearParentId () {
      this.$router.push({ name: 'fingerbankDevices' })
    },
    buildParentTree (parentId = 0, index = 0) {
      if (index === 0) this.$set(this, 'parentTree', [])
      if (~~parentId > 0) {
        this.$store.dispatch(`${this.storeName}/getDevice`, parentId).then(data => {
          this.$set(this.parentTree, index, data)
          if (data.parent_id) this.buildParentTree(data.parent_id, ++index)
        })
      }
    },
    resetSearch () {
      const { $refs: { pfConfigList: { resetSearch = () => {} } = {} } = {} } = this
      resetSearch()
    },
    changeScope (scope) {
      this.scope = scope
    }
  },
  watch: {
    scope: { // reset search when `scope` changes
      handler: function (a, b) {
        if (a !== b) {
          this.$set(this, 'config', config(this)) // reset config
          this.resetSearch() // reset search
        }
        this.buildParentTree() // clear parentTree
      }
    },
    parentId: { // reset search when `parentId` changes
      handler: function (a, b) {
        if (a !== b) {
          this.$set(this, 'config', config(this)) // reset config
        }
        this.buildParentTree(a) // build parentTree
      }
    }
  },
  mounted () {
    this.buildParentTree(this.parentId) // build parentTree
  }
}
</script>
