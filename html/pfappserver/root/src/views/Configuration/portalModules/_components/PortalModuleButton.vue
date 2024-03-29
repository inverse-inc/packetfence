<template>
  <div class="portal-module" :class="{ disabled: disabled }" @mouseout="delayHideButtons()">
    <transition name="slide-top-quick">
      <div class="front" @click="showButtons()" v-if="!buttonsVisible">
        <h6 class="text-truncate w-75"><icon :style="{ color: module.color }" name="circle" /> <span class="portal-module-type ml-1">{{ getModuleTypeName(module.type) }}</span></h6>
        <div class="portal-module-label w-75 text-truncate">{{ module.description }}</div>
      </div>
    </transition>
    <transition name="slide-bottom-quick" v-if="!disabled">
      <div class="back" @mouseover="keepButtons()" v-if="buttonsVisible">
        <b-button variant="link" class="m-auto text-primary" :to="{ name: 'portal_module', params: { id: module.id } }" @click="hideButtons()">
          <icon name="edit" />
        </b-button>
        <b-button variant="link" class="m-auto text-danger" @click="onRemove">
          <icon :name="isRoot? 'trash-alt' : 'unlink'" />
        </b-button>
      </div>
    </transition>
  </div>
</template>

<script>
import { createDebouncer } from 'promised-debounce'
import { moduleTypeName as getModuleTypeName } from '../config'

const props = {
  module: {
    type: Object,
    default: () => ({})
  },
  isRoot: {
    type: Boolean
  },
  disabled: {
    type: Boolean
  }
}

import { ref, toRefs } from '@vue/composition-api'
const setup = (props, context) => {

  const {
    module,
    disabled
  } = toRefs(props)

  const { emit } = context

  const buttonsVisible = ref(false)
  const buttonsHidden = ref(true)

  const showButtons = () => {
    if (!disabled.value) {
      buttonsVisible.value = true
      buttonsHidden.value = false
    }
  }

  const hideButtons = () => {
    buttonsVisible.value = false
    buttonsHidden.value = true
  }

  const keepButtons = () => {
    buttonsHidden.value = false
  }

  let $debouncer
  const delayHideButtons = () => {
    buttonsHidden.value = true
    if (!$debouncer)
      $debouncer = createDebouncer()
    $debouncer({
      handler: () => {
        if (buttonsHidden.value) {
          buttonsVisible.value = false
          buttonsHidden.value = true
        }
      },
      time: 1000 // 1 second
    })
  }

  const onRemove = () => {
    emit('remove', module.value.id)
    hideButtons()
  }

  return {
    getModuleTypeName,
    buttonsVisible,
    buttonsHidden,
    showButtons,
    hideButtons,
    delayHideButtons,
    keepButtons,
    onRemove
  }
}

// @vue/component
export default {
  name: 'portal-module-button',
  props,
  setup
}
</script>

<style lang="scss">
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
    max-width: $portal-module-width;
    margin: auto;
    text-align: center;
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

.disconnected .portal-module,
.minimize .disconnected .portal-module {
  flex-basis: 100%;
  border-width: $portal-module-border-width 0 0 0;
  margin-bottom: $portal-module-border-width;
  background-color: rgba($white, .2);
  background-position: 0 0%,0% 0,0 0%,100% 0%;
  background-size: $portal-module-border-width 16px;
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
    justify-content: center;
  }
  h6 {
    flex-shrink: 0;
    width: auto !important;
    padding: 0 map-get($spacers, 1);
    margin: 0;
    .fa-icon {
      margin: 0 map-get($spacers, 1) 0 0 !important;
    }
  }
  .portal-module-type {
    display: none;
  }
  .portal-module-label {
    width: auto !important;
    font-size: $figure-caption-font-size * .8;
    line-height: 1em;
    text-align: left;
    white-space: normal;
  }
}
</style>
