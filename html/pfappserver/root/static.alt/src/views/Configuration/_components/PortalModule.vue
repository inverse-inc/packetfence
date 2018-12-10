<template>
    <b-row align-v="center" class="portal-module-row row-nowrap" :class="{ first: index === 0, last: last }">
      <icon class="connector-arrow" name="caret-right"></icon>
      <portal-module-button :class="{ first: index === 0, last: last, leaf: !children }"
        :module="currentModule" :is-root="isRoot" v-bind="$attrs" @remove="remove"></portal-module-button>
      <b-col v-if="!isRoot && children" class="portal-module-col" :class="{ dragging: dragging }">
        <draggable v-model="children" :options="{ group: { name: path, pull: path, put: ['portal-module', path] }, ghostClass: 'portal-module-row-ghost', dragClass: 'portal-module-row-drag' }"
          @start="dragging = true" @end="dragging = false">
          <portal-module v-for="(mid, i) in children" :key="mid"
            :id="mid" n0parentId="id" :parents="childParents" :modules="modules" :storeName="storeName" :level="level + 1" :index="i" :last="i + 1 === children.length" />
        </draggable>
      </b-col>
    </b-row>
</template>

<script>
import draggable from 'vuedraggable'
import PortalModuleButton from './PortalModuleButton'

export default {
  name: 'portal-module',
  components: {
    draggable,
    PortalModuleButton
  },
  props: {
    storeName: {
      type: String,
      default: null,
      required: true
    },
    id: {
      type: String,
      default: null,
      required: true
    },
    module: {
      type: Object,
      default: null
    },
    parents: {
      type: Array,
      default: () => []
    },
    level: {
      type: Number,
      default: 0
    },
    index: {
      type: Number,
      default: 0
    },
    last: {
      type: Boolean,
      default: true
    },
    modules: {
      type: Array,
      default: () => []
    },
    isRoot: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      dragging: false,
      childParents: []
    }
  },
  computed: {
    currentModule () {
      return this.module || this.modules.find(module => module.id === this.id) || {}
    },
    children: {
      get () {
        return this.currentModule.modules ? this.currentModule.modules.filter(id => this.modules.find(module => module.id === id)) : false
      },
      set (newValue) {
        this.currentModule.modules = newValue
      }
    },
    path () {
      return 'L' + this.level + 'I' + this.index
    }
  },
  methods: {
    remove (id) {
      let list = [], index = -1
      if (this.parents.length > 0) {
        // Disconnect module from its parent
        let [parentId] = this.parents.slice(-1)
        let parentModule = this.modules.find(module => module.id === parentId)
        list = parentModule.modules
        index = list.findIndex(mid => mid === id)
      } else {
        // Delete module's definition
        list = this.modules
        index = list.findIndex(module => module.id === id)
      }
      if (index >= 0) {
        this.$delete(list, index)
      }
    }
  },
  created () {
    if (this.children) {
      this.childParents = [...this.parents, this.id]
    }
  }
}
</script>

<style lang="scss">
@import "../../../../node_modules/bootstrap/scss/functions";
@import "../../../styles/variables";

.connector-arrow {
  color: $portal-module-connector-color;
  transform: translateY($portal-module-connector-width/2);
}

.first.last > .connector-arrow {
  transform: none;
}

.row-nowrap {
  flex-wrap: nowrap;
}

.portal-module-col {
  padding-left: $portal-module-connector-margin;

  &::before {
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
  margin-left: 0;

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
    transform: translateY($portal-module-connector-width/2);
  }

  &.first::after {
    border-radius: $portal-module-connector-margin/2 0 0 0;
  }

  &::after {
    top: 50%;
    bottom: auto;
    border-top: $portal-module-connector-width solid $portal-module-connector-color;
  }
}

.portal-module-col.dragging > div > .portal-module-row {
  &::before, &::after {
    border-left: 0;
    border-radius: 0 !important;
  }
  .portal-module:hover {
    background-color: $white;
  }
}
.portal-module-row-ghost {
  &.last::before {
    border-bottom-style: dashed !important;
  }
  &::after {
    border-top-style: dashed !important;
  }
  .portal-module, .portal-module-col {
    display: none;
  }
}
.portal-module-row-drag {
  transform: scale(.8);
  background-color: transparent;
  &::before, &::after {
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
</style>
