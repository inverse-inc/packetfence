<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Roles') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_introduction_to_role_based_access_control" />
          </h4>
          <b-row v-if="parentTree.length > 0"
            class="mt-3">
            <b-col cols="auto">
              <b-button variant="link" class="px-0 mr-2 text-secondary" :to="{ name: 'roles' }">
                <icon name="times" variant="primary"></icon>
              </b-button>
              <b-button v-for="(parent, index) in parentTreeReverse" :key="parent.id" variant="link" class="px-0 mr-2 text-primary" :disabled="index === parentTree.length - 1" :to="{ name: 'rolesByParentId', params: { parentId: parent.id } }">
                <icon v-if="index > 0" name="caret-right" variant="text-secondary" class="mr-1"></icon>
                {{ parent.id }}
              </b-button>
            </b-col>
          </b-row>
        </b-card-header>
      </template>

      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newRole' }">{{ $t('New Role') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No roles found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(id)="item">
        <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="setParentId(item.id)">
          <span class="text-nowrap align-items-center ml-2">
            {{ item.id }} <icon name="plus-circle" class="ml-2"></icon>
          </span>
        </b-button>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap text-right">
          <pf-button-delete v-if="!item.not_deletable"
            size="sm" variant="outline-danger" class="mr-1"
            :disabled="isLoading" :confirm="$t('Delete Role?')"
            @on-delete="remove(item)"
            reverse
          />
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <b-button v-if="isInline" size="sm" variant="outline-primary" class="mr-1" :to="trafficShapingRoute(item.id)">{{ $t('Traffic Shaping') }}</b-button>
        </span>
      </template>
    </pf-config-list>

    <b-modal v-model="showDeleteErrorsModal" size="lg"
      centered lazy scrollable
      :no-close-on-backdrop="isLoading"
      :no-close-on-esc="isLoading"
    >
      <template v-slot:modal-title>
        {{ $t('Delete Role') }} <b-badge variant="secondary">{{ deleteId }}</b-badge>
      </template>
      <b-media no-body class="alert alert-danger">
        <icon name="exclamation-triangle" scale="2" v-slot:aside></icon>
        <div class="mx-2">{{ $t('The role could not be deleted. Either manually handle the following errors and try again, or re-reassign the resources to another existing role.') }}</div>
      </b-media>
      <h5>{{ $t('Role is still in use for:') }}</h5>
      <b-row v-for="error in deleteErrors" :key="error.reason">
        <b-col cols="auto" class="mr-auto">{{ reasons[error.reason] }}</b-col>
        <b-col cols="auto">{{ error.reason }}</b-col>
      </b-row>

      <template v-slot:modal-footer>
        <b-row class="w-100">
          <b-col cols="auto" class="mr-auto pl-0">
            <pf-form-select size="sm" class="d-inline"
              v-model="reassignRole"
              :options="reassignableRoles"
            />
            <b-button size="sm" class="ml-1" variant="outline-primary"  @click="reassign()" :disabled="isLoading">{{ $i18n.t('Reassign Role') }}</b-button>
          </b-col>
          <b-col cols="auto" class="pr-0">
            <b-button variant="secondary"  @click="showDeleteErrorsModal = false" :disabled="isLoading">{{ $i18n.t('Fix Manually') }}</b-button>
          </b-col>
        </b-row>
      </template>
    </b-modal>

  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormSelect from '@/components/pfFormSelect'
import { config, reasons } from '../_config/role'

export default {
  name: 'roles-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable,
    pfFormSelect
  },
  props: {
    parentId: {
      type: [String, Number],
      default: null
    }
  },
  data () {
    return {
      config: config(this),
      reasons,
      trafficShapingPolicies: [],
      deleteId: '',
      deleteErrors: [],
      showDeleteErrorsModal: false,
      roles: [],
      reassignRole: 'default',
      parentTree: []
    }
  },
  computed: {
    isInline () {
      return this.$store.getters['system/isInline']
    },
    isLoading () {
      return this.$store.getters['$_roles/isLoading']
    },
    reassignableRoles () {
      return this.roles
        .filter(role => role.id !== this.deleteId)
        .map(role => ({ text: role.id, value: role.id }))
    },
    parentTreeReverse () {
      // parentTree.reverse() issue within template, mutates Array immediately and causes infinite-loop w/ reactivity updates.
      return Array.prototype.slice.call(this.parentTree).reverse()
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneRole', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_roles/deleteRole', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      }).catch(error => {
        const { response: { data: { errors = [] } = {} } = {} } = error
        if (errors.length) {
        this.deleteId = item.id
          this.deleteErrors = errors
          this.showDeleteErrorsModal = true
        }
      })
    },
    reassign () {
      this.$store.dispatch('$_roles/reassignRole', { from: this.deleteId, to: this.reassignRole}).then(() => {
        this.showDeleteErrorsModal = false
        // cascade delete
        this.remove({ id: this.deleteId })
      })
    },
    trafficShapingRoute (id) {
      return (this.trafficShapingPolicies.includes(id))
        ? { name: 'traffic_shaping', params: { id } } // exists
        : { name: 'newTrafficShaping', params: { role: id } } // not exists
    },
    setParentId (id) {
      this.$router.push({ name: 'rolesByParentId', params: { parentId: id } })
    },
    clearParentId () {
      this.$router.push({ name: 'roles' })
    },
    buildParentTree (parentId, index = 0) {
      if (index === 0)
        this.$set(this, 'parentTree', [])
      if (parentId) {
        this.$store.dispatch('$_roles/getRole', parentId).then(data => {
          this.$set(this.parentTree, index, data)
          if (data.parent)
            this.buildParentTree(data.parent, ++index)
        })
      }
    }
  },
  mounted () {
    this.buildParentTree(this.parentId) // build parentTree
  },
  created () {
    this.$store.dispatch('$_roles/all').then(roles => {
      this.roles = roles
    })
    this.$store.dispatch('$_traffic_shaping_policies/all').then(response => {
      this.trafficShapingPolicies = response.map(policy => policy.id)
    })
  },
  watch: {
    parentId: { // reset search when `parentId` changes
      handler: function (a, b) {
        if (a !== b) {
          this.config = config(this) // reset config
        }
        this.buildParentTree(a) // build parentTree
      }
    }
  }
}
</script>
