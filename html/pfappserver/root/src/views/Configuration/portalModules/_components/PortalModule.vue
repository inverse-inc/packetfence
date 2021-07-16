<template>
  <div class="portal-module-path" :path="path">
    <b-row align-v="center" class="portal-module-row row-nowrap" :class="{ first: index === 0, last: (last && !isChained), disconnected: isChained, 'first-in-chain': firstInChain }">
      <icon v-if="!isChained" class="connector-arrow" name="caret-right" />
      <portal-module-button :class="{ first: index === 0, last: (last && (isRoot || !isChained)), leaf: !children }"
        :module="currentModule" :is-root="isRoot" v-bind="$attrs" @remove="onRemove" />
      <!-- vertical children -->
      <b-col v-if="!isRoot && !isChained && children" class="portal-module-col" :class="{ dragging: dragging }">
        <draggable v-model="children" :group="{ name: path, pull: path, put: ['portal-module', path] }" ghost-class="portal-module-row-ghost" drag-class="portal-module-row-drag"
          @start="dragging = true" @end="dragging = false">
          <portal-module v-for="(mid, i) in children" :key="`v-${mid}`"
            :id="mid" :parents="childParents" :modules="modules" :level="level + 1" :index="i" :last="i + 1 === children.length" />
        </draggable>
      </b-col>
    </b-row>
    <!-- horizontal (chained) children -->
    <draggable class="row row-nowrap portal-module-row align-items-center" :class="{ first: index === 0 && !last, last: last }" v-if="!isRoot && children && isChained" v-model="children" :group="{ name: path, pull: path, put: ['portal-module', path] }" ghost-class="portal-module-row-ghost" drag-class="portal-module-row-drag"
      @start="dragging = true" @end="dragging = false">
      <div v-for="(mid, i) in children" :key="`h-${mid}`" :class="{ 'col portal-module-col': (i > 0), dragging: dragging }">
        <portal-module :id="mid" :parents="childParents" :modules="modules" :level="level + i + 1" :first-in-chain="i === 0" :index="0" last />
      </div>
    </draggable>
  </div>
</template>

<script>
const draggable = () => import('vuedraggable')
import PortalModuleButton from './PortalModuleButton'
const components = {
  draggable,
  PortalModuleButton
}

const props = {
  id: {
    type: String,
    default: null
  },
  module: {
    type: Object,
    default: null
  },
  parents: {
    type: Array,
    default: () => ([])
  },
  level: {
    type: Number,
    default: 0
  },
  index: {
    type: Number,
    default: 0
  },
  firstInChain: {
    type: Boolean
  },
  last: {
    type: Boolean,
    default: true
  },
  modules: {
    type: Array,
    default: () => ([])
  },
  isRoot: {
    type: Boolean
  }
}

import { computed, onMounted, ref, toRefs } from '@vue/composition-api'
const setup = props => {

  const {
    id,
    module,
    modules,
    parents,
    level,
    index
  } = toRefs(props)

  const dragging = ref(false)
  const childParents = ref([])

  const currentModule = computed(() => {
    return module.value || modules.value.find(_module => _module.id === id.value) || {}
  })

  const isChained = computed(() => {
    return currentModule.value.type === 'Chained'
  })

  const children = computed(() => {
      if (currentModule.value.modules) {
        const _modules = currentModule.value.modules.filter(id => modules.value.find(module => module.id === id))
        if (_modules.length || currentModule.value.type === 'Root')
          return _modules
      }
      return false
  })

  const path = computed(() => {
    return 'L' + level.value + 'I' + index.value
  })

  const onRemove = id => {
    let list = []
    let _index = -1
    if (parents.value.length > 0) {
      // Disconnect module from its parent
      let [parentId] = parents.value.slice(-1)
      let parentModule = modules.value.find(module => module.id === parentId)
      list = parentModule.modules
      _index = list.findIndex(mid => mid === id)
    } else {
      // Delete module's definition
      list = modules.value
      _index = list.findIndex(module => module.id === id)
    }
    if (_index >= 0) {
      list.splice(_index, 1)
    }
  }

  onMounted(() => {
    if (children.value)
      childParents.value = [...parents.value, id.value]
  })

  return {
    dragging,
    childParents,
    currentModule,
    isChained,
    children,
    path,
    onRemove
  }
}

// @vue/component
export default {
  name: 'portal-module',
  components,
  props,
  setup
}
</script>

<style lang="scss">
.connector-arrow,
.connector-circle {
  position: absolute;
  color: $portal-module-connector-color;
}

.connector-arrow {
  left: 1.2rem;
  transform: translateY($portal-module-connector-width/2);
}

.connector-circle {
  height: .5em;
  transform: translateY(-$portal-module-connector-width/2);
}

.first.last > .connector-arrow {
  transform: translateY(-$portal-module-connector-width/2);
}

.first-in-chain > .connector-arrow {
  left: -.4rem;
}

.row-nowrap {
  flex-wrap: nowrap;
}

.portal-module-col {
  padding-right: 0;
  padding-left: $portal-module-connector-margin;

  &::before {
    // Leading horizontal line
    content: '';
    position: absolute;
    top: 0;
    right: 50%;
    left: 0;
    width: $portal-module-connector-margin;
    height: 50%;
    border-bottom: $portal-module-connector-width solid $portal-module-connector-color;
  }
}

.portal-module-row {
  position: relative;
  padding-left: $portal-module-connector-margin;
  margin: 0;

  &::before, &::after {
    content: '';
    position: absolute;
    top: 0;
    right: 50%;
    left: 0;
    width: $portal-module-connector-margin;
    height: 50%;
    border-left: $portal-module-connector-width solid $portal-module-connector-color;
  }

  &::after {
    top: 50%;
    bottom: auto;
    border-top: $portal-module-connector-width solid $portal-module-connector-color;
  }

  &.first::before, &.last::after {
    border: 0 none;
  }

  &.last::before {
    border-bottom: $portal-module-connector-width solid $portal-module-connector-color;
    border-radius: 0 0 0 $portal-module-connector-margin/2;
  }

  &:not(.first).last > .connector-arrow {
    transform: translateY(-$portal-module-connector-width/2);
  }

  &.first.last::before {
    border-radius: 0;
  }

  &.first::after {
    border-radius: $portal-module-connector-margin/2 0 0 0;
  }

  &.disconnected::after {
    border-top: 0;
  }

  &.first:not(.last).disconnected::after {
    content: none;
  }

  &.first-in-chain {
    padding-left: 0;
    &::before {
      content: none;
    }
  }

  &::after {
    top: 50%;
    bottom: auto;
    border-top: $portal-module-connector-width solid $portal-module-connector-color;
  }
}

.portal-module-col.dragging > div > div > .portal-module-row {
  &::before, &::after {
    border-left: 0;
    border-radius: 0 !important;
  }
  .portal-module:hover {
    background-color: $white;
  }
}

// The module in its new position
.portal-module-row-ghost {
  .portal-module-row.last::before {
    border-bottom-style: dashed !important;
    border-bottom-color: $portal-module-connector-hover-color;
  }
  .portal-module-row::after {
    border-top-style: dashed !important;
    border-top-color: $portal-module-connector-hover-color;
  }

  .connector-arrow {
    color: $portal-module-connector-hover-color;
  }
  .portal-module, .portal-module-col {
    opacity: 0.5;
  }
}

// The module following the mouse pointer
.portal-module-row-drag {
  transform: scale(.8);
  background-color: transparent;
  .portal-module-row::before, .portal-module-row::after {
    border: 0 !important;
    border-radius: 0 !important;
  }
  .connector-arrow {
    color: transparent;
  }
}
.disconnect {
  .portal-module-row.last::before {
    border: 0 none;
  }
  .connector-arrow {
    display: none;
  }
  .portal-module-row-ghost {
    .portal-module, .portal-module-col {
      display: inherit;
    }
  }
}
.debug {
  .portal-module-row {
    border: 1px dashed pink;
    margin: 4px;
  }
  .portal-module-path::before {
    content: attr(path);
    position: absolute;
    z-index: 2;
    margin-top: 4px;
    margin-left: 9px;
    background-color: deeppink;
    color: white;
    font-family: "IBM Plex Mono";
    font-size: .5rem;
    font-weight: 800;
  }
}
</style>
