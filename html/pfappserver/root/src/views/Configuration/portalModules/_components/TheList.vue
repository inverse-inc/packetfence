<template>
  <b-card no-body ref="container" class="h-100">
    <b-card-header>
      <h4 class="mb-0">
        {{ $t('Portal Modules') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_portal_modules" />
      </h4>
    </b-card-header>
    <!-- Visual representation of portal modules -->
    <b-tabs class="flex-grow-1" :class="{ minimize: minimize }" v-scroll100 v-model="tabIndex" card>
      <b-tab v-for="rootModule in rootModules" :key="rootModule.id" :title="rootModule.description">
        <b-form-row class="justify-content-end">
          <b-button variant="link" @click="minimize = !minimize"><icon :name="minimize ? 'expand' : 'compress'"></icon></b-button>
          <base-button-confirm
            variant="danger" class="mr-1" reverse
            :disabled="isLoading"
            :confirm="$t('Delete Module?')"
            @click="onRemove(rootModule.id)"
          >{{ $t('Delete') }}</base-button-confirm>
          <b-form @submit.prevent="onSave(rootModule)">
            <base-button-save type="submit" :isLoading="isLoading">
              {{ $t('Save') }}
            </base-button-save>
          </b-form>
        </b-form-row>
        <div class="position-relative">
          <div class="steps-row">
            <template v-for="step in stepsCount(rootModule.id)">
            <icon class="card-bg" name="caret-right" :key="`${step}-icon`" v-show="!minimize"><!-- force proper spacing --></icon>
            <div class="step-col" :key="`${step}-div`">
              <div class="step">
                <div class="float-right py-1 pr-2 text-secondary small"><span v-show="!minimize" v-t="'step'"></span> {{ step }}</div>
              </div>
            </div>
            </template>
          </div>
          <b-row align-v="center" class="pt-5 pl-3 row-nowrap">
            <icon class="connector-circle" name="circle"></icon>
            <portal-module :index="0" :id="rootModule.id" :modules="items" :minimize="minimize" />
          </b-row>
        </div>
      </b-tab>
      <template v-slot:tabs-end>
        <b-button class="nav-item ml-3 mb-1" variant="outline-primary" :to="{ name: 'newPortalModule', params: { moduleType: 'Root' } }">{{ $t('New Root Module') }}</b-button>
      </template>
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
        <b-tab title-link-class="text-nowrap" v-for="(moduleType, moduleIndex) in activeModuleTypes" :key="`${moduleType.name}-${moduleIndex}`">
          <template v-slot:title><icon :style="{ color: getColorByType(moduleType) }" name="circle" scale=".5"></icon> {{ getModuleTypeName(moduleType) }}</template>
          <draggable tag="b-row" :list="getModulesByType(moduleType)" :move="validateMove"
            :group="{ name: 'portal-module', pull: 'clone', revertClone: true, put: false }"
            ghost-class="portal-module-row-ghost" drag-class="portal-module-row-drag">
            <portal-module v-for="(mid, i) in getModulesByType(moduleType)" :key="mid"
              :index="i" :id="mid" :module="getModule(mid)" :modules="items" v-show="mid" is-root />
          </draggable>
        </b-tab>
        <template v-slot:tabs-end>
          <b-dropdown :text="$t('New Module')" class="nav-item text-nowrap pr-3 ml-3 mb-1" size="sm" variant="outline-primary" :boundary="$refs.container">
            <template v-for="(group, groupIndex) in moduleTypes">
              <b-dropdown-header class="text-secondary px-2" v-t="group.name" :key="`${group.name}-${groupIndex}`"></b-dropdown-header>
              <b-dropdown-item v-for="(moduleType, moduleIndex) in group.types" :key="`${moduleType.name}-${moduleIndex}`" :to="{ name: 'newPortalModule', params: { moduleType: moduleType.type } }">
                <icon :style="{ color: moduleType.color }" class="mb-1" name="circle" scale=".5"></icon> {{ moduleType.name }}
              </b-dropdown-item>
              <b-dropdown-divider :key="group.name"></b-dropdown-divider>
            </template>
          </b-dropdown>
        </template>
      </b-tabs>
    </b-card-footer>
  </b-card>
</template>

<script>
const draggable = () => import('vuedraggable')
import {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseButtonSave
} from '@/components/new/'
import PortalModule from './PortalModule'
const components = {
  draggable,
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseButtonSave,
  PortalModule
}

import { scroll100 } from '@/directives/'
const directives = {
  scroll100
}

import {
  moduleTypes as getModuleTypes,
  moduleTypeName as getModuleTypeName
} from '../config'

import { computed, ref, toRefs } from '@vue/composition-api'
import { useSearch, useStore } from '../_composables/useCollection'
const setup = (props, context) => {

  const { root: { $store } = {} } = context
  const {
    updateItem,
    deleteItem
  } = useStore($store)

  const search = useSearch()
  const {
    doReset,
    reSearch
  } = search
  const {
    items,
    isLoading
  } = toRefs(search)

  // automatically search (default)
  doReset()

  const moduleTypes = ref(getModuleTypes())
  const tabIndex = ref(0)
  const minimize = ref(false)

  const rootModules = computed(() => items.value.filter(module => module.type === 'Root'))
  const activeModuleTypes = computed(() => {
    let types = {}
    let sortedTypes = []
    items.value.forEach(module => {
      if (module.type !== 'Root')
        types[module.type] = true
    })
    moduleTypes.value.forEach(group => {
      group.types.forEach(item => {
        if (types[item.type])
          sortedTypes.push(item.type)
      })
    })
    return sortedTypes
  })

  const getModule = id => {
    let module = items.value.find(module => module.id === id)
    if (module)
      module.color = getColorByType(module.type)
    return module
  }

  const getModulesByType = type => {
    const modules = items.value.filter(module => module.type === type).map(module => module.id)
    return [undefined, ...modules]
  }

  const getColorByType = type => {
    let moduleType
    moduleTypes.value.some(group => {
      moduleType = group.types.find(item => {
        return item.type === type
      })
      return moduleType
    })
    if (moduleType)
      return moduleType.color
    else
      return 'black'
  }

  const stepsCount = rootId => {
    let count = 0
    let rootModule = getModule(rootId)
    let _module = (id, level) => {
      let module = getModule(id)
      if (module) {
        let modules = module.modules
        let mlevel = level
        const isChained = (module.type === 'Chained')
        if (!isChained)
          mlevel++
        if (mlevel > count)
          count = mlevel
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
    if (rootModule)
      _module(rootModule.id, 0)
    return count
  }

  const validateMove = event => {
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
  }

  const onSave = module => {
    updateItem(module)
    if (module.modules) {
      module.modules.forEach(mid => {
        const childModule = {
          ...getModule(mid),
          ...{ quiet: true }
        }
        onSave(childModule)
      })
    }
  }

  const onRemove = id => {
    const index = items.value.findIndex(module => module.id === id)
    if (index >= 0) {
      deleteItem({ id })
        .then(() => reSearch())
    }
  }

  return {
    isLoading,
    items,
    moduleTypes,
    getModuleTypeName,
    tabIndex,
    minimize,
    rootModules,
    activeModuleTypes,
    getModule,
    getModulesByType,
    getColorByType,
    stepsCount,
    validateMove,
    onSave,
    onRemove
  }
}

// @vue/component
export default {
  name: 'the-list',
  components,
  directives,
  setup
}
</script>

<style lang="scss">
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
  overflow-y: hidden;
  height: 20vh;
  min-height: 12rem;
  padding: 0;
  .card-header-tabs {
    // TODO: switch to icon-only when viewport is too small
    flex-wrap: nowrap;
  }
}
</style>