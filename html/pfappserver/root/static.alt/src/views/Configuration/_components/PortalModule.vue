<template>
    <b-row align-v="center" class="portal-module-row row-nowrap text-center" :class="{ first: index === 0, last: last }">
      <icon class="connector-arrow" name="caret-right"></icon>
      <portal-module-button :class="{ first: index === 0, last: last, leaf: !children }"
        :module="module" :disabled="!parentId" @remove="remove"></portal-module-button>
      <b-col v-if="children" class="portal-module-col">
        <portal-module v-for="(mid, i) in children" :key="mid"
          :id="mid" :parentId="id" :modules="modules" :storeName="storeName" :level="level + 1" :index="i" :last="i + 1 === children.length" />
      </b-col>
    </b-row>
</template>

<script>
import PortalModuleButton from './PortalModuleButton'

export default {
  name: 'portal-module',
  components: {
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
    parentId: {
      type: String,
      default: null
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
      default: () => [],
      required: true
    }
  },
  computed: {
    module () {
      return this.modules.find(module => module.id === this.id) || {}
    },
    children () {
      return this.module.modules ? this.module.modules.filter(id => this.modules.find(module => module.id === id)) : false
    }
  },
  methods: {
    remove (id) {
      let parentModule = this.modules.find(module => module.id === this.parentId)
      const index = parentModule.modules.findIndex(mid => mid === id)
      if (index >= 0) {
        this.$delete(parentModule.modules, index)
      }
    }
  }
}
</script>

<style lang="scss">
@import "../../../../node_modules/bootstrap/scss/functions";
@import "../../../styles/variables";

.connector-arrow {
  color: $portal-module-connector-color;
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
    transform: translateY(-$portal-module-connector-width/2);
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
</style>
