<template>
  <b-card class="h-100" no-body>
    <!-- Visual representation of portal modules -->
    <b-tabs class="tab-pane-scroll flex-grow-1" :class="{ minimize: minimize }" v-model="tabIndex" card>
      <b-tab v-for="rootModule in rootModules" :key="rootModule.id" :title="rootModule.description">
        <b-form-row class="justify-content-end">
          <b-button variant="link" @click="minimize = !minimize"><icon :name="minimize ? 'expand' : 'compress'"></icon></b-button>
          <pf-button-delete class="mr-1" :disabled="isLoading" :confirm="$t('Delete Module?')" @on-delete="remove(rootModule.id)"/>
          <b-form @submit.prevent="save(rootModule)">
            <pf-button-save :disabled="invalidForm" :isLoading="isLoading" v-t="'Save'"></pf-button-save>
          </b-form>
        </b-form-row>
        <div class="position-relative">
          <div class="steps-row">
            <template v-for="step in stepsCount(rootModule.id)">
            <icon class="card-bg" name="caret-right" :key="step"><!-- force proper spacing --></icon>
            <div class="step-col" :key="step">
              <div class="step">
                <div class="float-right py-1 pr-2 text-secondary small"><span v-show="!minimize" v-t="'step'"></span> {{ step }}</div>
              </div>
            </div>
            </template>
          </div>
          <b-row align-v="center" class="pt-5 pl-3 row-nowrap">
            <icon class="connector-circle" name="circle"></icon>
            <portal-module :id="rootModule.id" :modules="items" :storeName="storeName" :minimize="minimize" />
          </b-row>
        </div>
      </b-tab>
      <b-button class="ml-3 mb-1" variant="outline-primary" slot="tabs" :to="{ name: 'newPortalModule', params: { moduleType: 'Root' } }">{{ $t('New Root Module') }}</b-button>
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
        <b-tab title-link-class="text-nowrap" v-for="moduleType in activeModuleTypes" :key="moduleType">
          <template slot="title"><icon :style="{ color: getColorByType(moduleType) }" name="circle" scale=".5"></icon> {{ getModuleTypeName(moduleType) }}</template>
          <draggable element="b-row" :list="getModulesByType(moduleType)" :move="validateMove"
            :options="{ group: { name: 'portal-module', pull: 'clone', revertClone: true, put: false }, ghostClass: 'portal-module-row-ghost', dragClass: 'portal-module-row-drag' }">
            <portal-module :id="mid" v-for="mid in getModulesByType(moduleType)" :module="getModule(mid)" :modules="items" :key="mid" :storeName="storeName" v-show="mid" is-root></portal-module>
          </draggable>
        </b-tab>
        <b-dropdown :text="$t('New Module')" class="text-nowrap pr-3 ml-3 mb-1" size="sm" variant="outline-primary" boundary="viewport" slot="tabs">
          <template v-for="group in moduleTypes">
            <b-dropdown-header class="text-secondary" v-t="group.name" :key="group.name"></b-dropdown-header>
            <b-dropdown-item v-for="moduleType in group.types" :key="moduleType.name" :to="{ name: 'newPortalModule', params: { moduleType: moduleType.type } }">
              <icon :style="{ color: moduleType.color }" class="mb-1" name="circle" scale=".5"></icon> {{ moduleType.name }}
            </b-dropdown-item>
            <b-dropdown-divider :key="group.name"></b-dropdown-divider>
          </template>
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
import {
  pfConfigurationPortalModuleTypes as moduleTypes,
  pfConfigurationPortalModuleTypeName as moduleTypeName
} from '@/globals/configuration/pfConfigurationPortalModules'

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
    searchableOptions: {
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
      moduleTypes: moduleTypes(),
      getModuleTypeName: moduleTypeName,
      tabIndex: 0,
      minimize: false,
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
      pageSizeLimit: 1000,
      parentNodes: []
    }
  },
  computed: {
    rootModules () {
      return this.items.filter(module => module.type === 'Root')
    },
    activeModuleTypes () {
      let types = {}
      let sortedTypes = []
      this.items.forEach(module => {
        if (module.type !== 'Root') {
          types[module.type] = true
        }
      })
      this.moduleTypes.forEach(group => {
        group.types.forEach(item => {
          if (types[item.type]) {
            sortedTypes.push(item.type)
          }
        })
      })
      return sortedTypes
    }
  },
  methods: {
    getModule (id) {
      let module = this.items.find(module => module.id === id)
      if (module) {
        module.color = this.getColorByType(module.type)
      }
      return module
    },
    getModulesByType (type) {
      const modules = this.items.filter(module => module.type === type).map(module => module.id)
      return [undefined, ...modules]
    },
    getColorByType (type) {
      let moduleType
      this.moduleTypes.some((group) => {
        moduleType = group.types.find((item) => {
          return item.type === type
        })
        return moduleType
      })
      if (moduleType) {
        return moduleType.color
      } else {
        return 'black'
      }
    },
    stepsCount (rootId) {
      let count = 0
      let rootModule = this.getModule(rootId)
      let _module = (id, level) => {
        let module = this.getModule(id)
        if (module) {
          let modules = module.modules
          let mlevel = level
          const isChained = (module.type === 'Chained')
          if (!isChained) {
            mlevel++
          }
          if (mlevel > count) {
            count = mlevel
          }
          let maxLevel = mlevel
          if (modules) {
            modules.forEach(mid => {
              if (isChained) {
                maxLevel = _module(mid, maxLevel)
              } else {
                maxLevel = Math.max(maxLevel, _module(mid, mlevel))
              }
            })
          }
          return maxLevel
        }
        return level
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
    save (module) {
      this.$store.dispatch(`${this.storeName}/updatePortalModule`, module)
      if (module.modules) {
        module.modules.forEach(mid => {
          const childModule = {
            ...this.getModule(mid),
            ...{ quiet: true }
          }
          this.save(childModule)
        })
      }
    },
    remove (id) {
      const index = this.items.findIndex(module => module.id === id)
      if (index >= 0) {
        this.$store.dispatch(`${this.storeName}/deletePortalModule`, id).then(response => {
          this.$delete(this.items, index)
        })
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
.steps-row {
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  left: 0;
  display: flex;

  .step-col {
    min-width: $portal-module-width + $portal-module-connector-margin * 2;
    transition: all 300ms ease;
    .step {
      height: 100%;
      border-radius: $border-radius;
      margin: 1rem;
      box-shadow: .25rem .25rem 1rem rgba(0,0,0,.15)!important;
      background-color: $body-bg;
      opacity: .6;
    }
  }
}

/* Dense version */
.minimize .steps-row .step-col {
  min-width: $portal-module-width/2 + $portal-module-connector-margin * 2;
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
