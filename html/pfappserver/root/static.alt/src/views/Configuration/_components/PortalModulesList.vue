<template>
  <b-card class="h-100" no-body>
    <!-- Visual representation of portal modules -->
    <b-tabs class="tab-pane-scroll flex-grow-1" v-model="tabIndex" card>
      <b-tab v-for="rootModule in rootModules" :key="rootModule.id" :title="rootModule.description">
        <b-form-row class="justify-content-end">
          <b-button variant="link" @click="expand = !expand"><icon :name="expand ? 'compress' : 'expand'"></icon></b-button>
          <pf-button-delete class="mr-1" :disabled="isLoading" :confirm="$t('Delete Module?')" @on-delete="remove(rootModule.id)"/>
          <pf-button-save :disabled="invalidForm" :isLoading="isLoading" v-t="Save"></pf-button-save>
        </b-form-row>
        <div class="position-relative">
          <div class="pages-row">
            <template v-for="page in pagesCount(rootModule.id)">
            <icon class="card-bg" name="caret-right" :key="page"><!-- force proper spacing --></icon>
            <div class="page-col" :key="page">
              <div class="page">
                <icon class="ml-2 text-danger" name="circle" scale=".5"></icon>
                <icon class="ml-1 text-warning" name="circle" scale=".5"></icon>
                <icon class="ml-1 text-success" name="circle" scale=".5"></icon>
                <div class="float-right py-1 pr-2 text-secondary small">{{ $t('page') }} {{ page }}</div>
              </div>
            </div>
            </template>
          </div>
          <b-row align-v="center" class="pt-5">
            <icon class="connector-arrow" name="circle"></icon>
            <portal-module :id="rootModule.id" :modules="items" :storeName="storeName" />
          </b-row>
        </div>
      </b-tab>
      <b-button class="ml-3 mb-1" variant="outline-primary" slot="tabs">{{ $t('Add Root Module') }}</b-button>
      <!-- Loading progress indicator -->
      <b-container class="my-5" v-if="isLoading && !items.length">
        <b-row class="justify-content-md-center text-secondary">
          <b-col cols="12" md="auto">
            <icon name="circle-notch" scale="1.5" spin></icon>
          </b-col>
        </b-row>
      </b-container>
    </b-tabs>
    <!-- All portal modules grouped by type -->
    <b-card-footer class="card-footer-fixed disconnect">
      <b-tabs small card>
        <b-tab v-for="type in moduleTypes" :key="type" :title="$t(type)">
            <draggable element="b-row" :list="getModulesByType(type)" :move="validateMove"
              :options="{ group: { name: 'portal-module', pull: 'clone', revertClone: true, put: false }, ghostClass: 'portal-module-row-ghost', dragClass: 'portal-module-row-drag' }">
              <portal-module :id="mid" v-for="mid in getModulesByType(type)" :module="getModule(mid)" :modules="items" :key="mid" :storeName="storeName" v-show="mid" is-root />
            </draggable>
        </b-tab>
        <b-dropdown :text="$t('Add Module')" class="ml-3 mb-1" size="sm" variant="outline-primary" slot="tabs">
          <b-dropdown-header class="text-secondary" v-t="'Multiple'"></b-dropdown-header>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Choice' } }" v-t="'Choice'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Chained' } }" v-t="'Chained'"></b-dropdown-item>
          <b-dropdown-divider></b-dropdown-divider>
          <b-dropdown-header class="text-secondary" v-t="'Authentication'"></b-dropdown-header>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::Billing' } }" v-t="'Billing'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::Blackhole' } }" v-t="'Blackhole'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::Email' } }" v-t="'Email'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::Login' } }" v-t="'Login'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::Null' } }" v-t="'Null'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::OAuth::Facebook' } }" v-t="'Facebook'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::OAuth::Github' } }" v-t="'Github'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::OAuth::Google' } }" v-t="'Google'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::OAuth::Instagram' } }" v-t="'Instagram'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::OAuth::LinkedIn' } }" v-t="'LinkedIn'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::OAuth::OpenID' } }" v-t="'OpenID'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::OAuth::Pinterest' } }" v-t="'Pinterest'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::OAuth::Twitter' } }" v-t="'Twitter'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::OAuth::WindowsLive' } }" v-t="'WindowsLive'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::SAML' } }" v-t="'SAML'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::SMS' } }" v-t="'SMS'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Authentication::Sponsor' } }" v-t="'Sponsor'"></b-dropdown-item>
          <b-dropdown-divider></b-dropdown-divider>
          <b-dropdown-header class="text-secondary" v-t="'Other'"></b-dropdown-header>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'FixedRole' } }" v-t="'Fixed Role'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Message' } }" v-t="'Message'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Provisioning' } }" v-t="'Provisioning'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'SelectRole' } }" v-t="'Select Role'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'Survey' } }" v-t="'Survey'"></b-dropdown-item>
            <b-dropdown-item :to="{ name: 'newPortalModule', params: { type: 'URL' } }" v-t="'URL'"></b-dropdown-item>
        </b-dropdown>
      </b-tabs>
    </b-card-footer>
  </b-card>
</template>

<script>
import pfMixinSearchable from '@/components/pfMixinSearchable'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import draggable from 'vuedraggable'
import PortalModule from './PortalModule'
import PortalModuleButton from './PortalModuleButton'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'

export default {
  name: 'PortalModulesList',
  mixins: [
    pfMixinSearchable
  ],
  components: {
    draggable,
    PortalModule,
    PortalModuleButton,
    pfButtonSave,
    pfButtonDelete
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    pfMixinSearchableOptions: {
      type: Object,
      default: () => ({
        searchApiEndpoint: 'config/portal_modules',
        defaultSortKeys: ['id'],
        defaultSearchCondition: {
          op: 'and',
          values: [{
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: null },
              { field: 'description', op: 'contains', value: null }
            ]
          }]
        },
        defaultRoute: { name: 'portal_modules' }
      })
    }
  },
  data () {
    return {
      tabIndex: 0,
      expand: true,
      columns: [
        {
          key: 'id',
          label: this.$i18n.t('Name'),
          sortable: true,
          visible: true
        },
        {
          key: 'description',
          label: this.$i18n.t('Description'),
          sortable: true,
          visible: true
        },
        {
          key: 'type',
          label: this.$i18n.t('Type'),
          sortable: true,
          visible: true
        }
      ],
      fields: [
        {
          value: 'id',
          text: 'Name',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'description',
          text: 'Description',
          types: [conditionType.SUBSTRING]
        },
        {
          value: 'type',
          text: 'Type',
          types: [conditionType.SUBSTRING]
        }
      ],
      requestPage: 1,
      currentPage: 1,
      pageSizeLimit: 10,
      parentNodes: []
    }
  },
  computed: {
    rootModules () {
      return this.items.filter(module => module.type === 'Root')
    },
    moduleTypes () {
      let types = {}
      this.items.forEach(module => {
        if (module.type !== 'Root') {
          types[module.type] = true
        }
      })
      return Object.keys(types)
    }
  },
  methods: {
    getModule (id) {
      return this.items.find(module => module.id === id)
    },
    getModulesByType (type) {
      const modules = this.items.filter(module => module.type === type).map(module => module.id)
      return [undefined, ...modules]
    },
    pagesCount (rootId) {
      let count = 0
      let rootModule = this.getModule(rootId)
      let _module = (id, level) => {
        let module = this.getModule(id)
        if (module) {
          let modules = module.modules
          let mlevel = level + 1
          if (mlevel > count) {
            count = mlevel
          }
          if (modules) {
            modules.forEach(mid => {
              _module(mid, mlevel)
            })
          }
        }
      }
      if (rootModule) {
        _module(rootModule.id, 0)
      }
      return count
    },
    validateMove (event) {
      // Validate destination list when dragging a module:
      // - Don't allow duplicated modules;
      // - Don't allow a module to be its own grandchild
      if (event.draggedContext && event.relatedContext) {
        const mid = event.draggedContext.element
        const destinationList = event.relatedContext.list
        const destinationComponent = event.relatedContext.component // draggable component
        let parents = []
        if (destinationComponent.$children) {
          let [firstModule] = destinationComponent.$children
          if (firstModule && firstModule.parents) {
            parents = firstModule.parents
          }
        }
        return !destinationList.find(id => id === mid) && !parents.find(id => id === mid)
      }
      return false
    },
    remove (id) {
      const index = this.items.findIndex(module => module.id === id)
      if (index >= 0) {
        this.$delete(this.items, index)
      }
    }
  },
  mounted () {
    if (this.parentNodes.length === 0) {
      // Find all parent DOM nodes
      let parentNode = this.$el.parentNode
      while (parentNode && 'classList' in parentNode) {
        this.parentNodes.push(parentNode)
        parentNode = parentNode.parentNode
      }
    }
    // Force all parent nodes to take 100% of the window height
    this.parentNodes.forEach(node => {
      node.classList.add('h-100')
    })
  },
  beforeDestroy () {
    // Remove height constraint on all parent nodes
    this.parentNodes.forEach(node => {
      node.classList.remove('h-100')
    })
  }
}
</script>

<style lang="scss">
@import "../../../../node_modules/bootstrap/scss/functions";
@import "../../../styles/variables";

.tab-pane-scroll {
  overflow: auto;
}
.card-bg {
  color: $card-bg;
}
.pages-row {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;

  .page-col {
    min-width: $portal-module-width + $portal-module-connector-margin * 2;

    .page {
      height: 100%;
      border-radius: $border-radius;
      margin: 1rem;
      box-shadow: .25rem .25rem 1rem rgba(0,0,0,.15)!important;
      background-color: $body-bg;
      opacity: .6;
    }
  }
}
.card-footer-fixed {
  overflow: auto;
  height: 20vh;
  min-height: 12rem;
  padding: 0;
  .card-header-tabs {
    // TODO: switch to icon-only when viewport is too small
    flex-wrap: nowrap;
  }
}
</style>
