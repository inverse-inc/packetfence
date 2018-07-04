<template>
  <b-button-group :size="size">
    <b-button 
      v-if="interrupt" 
      type="button" 
      variant="danger"
      @click.stop="onDelete($event)"
      @mouseover="startInterrupt($event)" 
      @mouseleave="stopInterrupt($event)"
      >{{ $t('Delete') }}</b-button>
    <b-button 
      v-if="interrupt" 
      type="button" 
      variant="warning" 
      @click.stop="stopInterrupt($event)" 
      @mousemove="startInterrupt($event)" 
      @mouseover="startInterrupt($event)" 
      @mouseleave="stopInterrupt($event)"
      >{{ $t('Cancel') }}</b-button>
    <b-button 
      v-if="interrupt" 
      type="button" 
      variant="outline-secondary" 
      disabled
      >{{ confirm }}</b-button>
    <b-button 
      v-if="!interrupt" 
      type="button" 
      :variant="variant" 
      :disabled="disabled"
      @click="startInterrupt($event)"
      ><slot>{{ $t('Delete') }}</slot></b-button>
  </b-button-group>
</template>

<script>
import i18n from '@/utils/locale'

export default {
  name: 'delete-button',
  props: {
    variant: {
      type: String,
      default: 'outline-danger'
    },
    size: {
      type: String,
      default: ''
    },
    confirm: {
      type: String,
      default: i18n.t('Are you sure?')
    },
    interrupt: {
      type: Boolean,
      default: false
    },
    timeout: {
      type: Number,
      default: 3000
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  methods: {
    startInterrupt (event) {
      if (this.timer) clearTimeout(this.timer)
      this.interrupt = true
      this.timer = setTimeout(this.stopInterrupt, this.timeout)
    },
    stopInterrupt (event) {
      if (this.timer) clearTimeout(this.timer)
      this.interrupt = false
    },
    onDelete (event) {
      // emit to parent
      this.$emit('on-delete', event)
    }
  }
}
</script>
