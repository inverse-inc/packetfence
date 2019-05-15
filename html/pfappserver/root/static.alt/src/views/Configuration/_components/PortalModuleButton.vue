<template>
  <div class="portal-module" :class="{ disabled: disabled }" @mouseout="delayHideButtons()">
    <transition name="slide-top-quick">
      <div class="front" @click="showButtons()" v-if="!buttonsVisible">
        <h6 class="text-truncate"><icon class="mb-1" :style="{ color: module.color }" name="circle"></icon> <span class="portal-module-type ml-1">{{ getModuleTypeName(module.type) }}</span></h6>
        <div class="portal-module-label text-truncate">{{ module.description }}</div>
      </div>
    </transition>
    <transition name="slide-bottom-quick" v-if="!disabled">
      <div class="back" @mouseover="keepButtons()" v-if="buttonsVisible">
        <b-button variant="link" class="m-auto text-primary" :to="{ name: 'portal_module', params: { id: module.id } }" @click="hideButtons()">
          <icon name="edit"></icon>
        </b-button>
        <b-button variant="link" class="m-auto text-danger" @click="remove">
          <icon :name="isRoot? 'trash-alt' : 'unlink'"></icon>
        </b-button>
      </div>
    </transition>
  </div>
</template>

<script>
import { createDebouncer } from 'promised-debounce'
import { pfConfigurationPortalModuleTypeName as moduleTypeName } from '@/globals/configuration/pfConfigurationPortalModules'


export default {
  name: 'portal-module-button',
  props: {
    module: {
      type: Object,
      default: () => {},
      required: true
    },
    isRoot: {
      type: Boolean,
      default: false
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      getModuleTypeName: moduleTypeName,
      buttonsVisible: false,
      buttonsHidden: true
    }
  },
  methods: {
    showButtons () {
      if (!this.disabled) {
        this.buttonsVisible = true
        this.buttonsHidden = false
      }
    },
    hideButtons () {
      this.buttonsVisible = false
      this.buttonsHidden = true
    },
    keepButtons () {
      this.buttonsHidden = false
    },
    delayHideButtons () {
      let _this = this
      this.buttonsHidden = true
      if (!this.$debouncer) {
        this.$debouncer = createDebouncer()
      }
      this.$debouncer({
        handler: () => {
          if (_this.buttonsHidden) {
            _this.buttonsVisible = false
            _this.buttonsHidden = true
          }
        },
        time: 1000 // 1 second
      })
    },
    remove (event) {
      this.$emit('remove', this.module.id)
      this.hideButtons()
    }
  }
}
</script>

<style lang="scss">
@import "../../../../node_modules/bootstrap/scss/functions";
@import "../../../styles/variables";

.portal-module {
  position: relative;
  flex: 0 0 $portal-module-width;
  align-items: center;
  overflow: hidden;
  min-width: $portal-module-width;
  padding: 1rem;
  border: solid $portal-module-border-color;
  border-width: 0 $portal-module-border-width;
  margin: .5rem 0;
  // Square bracket effect
  background-color: $white;
  background-image: linear-gradient($portal-module-border-color, $portal-module-border-color),
    linear-gradient($portal-module-border-color, $portal-module-border-color),
    linear-gradient($portal-module-border-color, $portal-module-border-color),
    linear-gradient($portal-module-border-color, $portal-module-border-color);
  background-position: top left, top right, bottom left, bottom right;
  background-size: 8px $portal-module-border-width;
  background-repeat: no-repeat;
  transition: all 300ms ease;

  &:not(.disabled) {
    cursor: pointer;
  }

  &::before {
    content: '';
    display: block;
    height: $portal-module-height;
  }

  .front, .back {
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    left: 0;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
  }
  .back {
    flex-direction: row;
  }
  .portal-module-label {
    font-size: $figure-caption-font-size;
  }
}

.portal-module:hover {
  border-color: $portal-module-connector-hover-color;
  background-color: $portal-module-hover-bg;
  background-image: linear-gradient($portal-module-connector-hover-color, $portal-module-connector-hover-color),
    linear-gradient($portal-module-connector-hover-color, $portal-module-connector-hover-color),
    linear-gradient($portal-module-connector-hover-color, $portal-module-connector-hover-color),
    linear-gradient($portal-module-connector-hover-color, $portal-module-connector-hover-color);
  + .portal-module-col::before,
  + .portal-module-col .portal-module-col::before,
  + .portal-module-col .portal-module-row::before,
  + .portal-module-col .portal-module-row::after {
    border-color: $portal-module-connector-hover-color;
  }
  + .portal-module-col .portal-module-row .connector-arrow {
    color: $portal-module-connector-hover-color;
  }
}

/* Dense version */
.minimize .portal-module {
  flex: 0 0 $portal-module-width/2;
  min-width: $portal-module-width/2;
  &::before {
    height: 1rem;
  }
  .front {
    flex-direction: row;
    margin: map-get($spacers, 1);
  }
  h6 {
    flex-shrink: 0;
    margin: 0;
    .fa-icon {
      margin: 0 map-get($spacers, 1) 0 0 !important;
    }
  }
  .portal-module-type {
    display: none;
  }
  .portal-module-label {
    flex-grow: 1;
    font-size: $figure-caption-font-size * .8;
    line-height: 1em;
    text-align: left;
    white-space: normal;
  }
}
</style>
