<template>
  <b-form-group horizontal :label-cols="(label) ? labelCols : 0" :label="$t(label)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()" :class="{ 'mb-0': !label }">
    <b-form-textarea 
      v-model="inputValue"
      v-bind="$attrs"
      :state="isValid()"
      @input.native="validate()"
      @keyup.native="onChange($event)"
      @change.native="onChange($event)"
    ></b-form-textarea>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-input',
  mixins: [
    pfMixinValidation
  ],
  props: {
    value: {
      default: null
    },
    label: {
      type: String,
      default: null
    },
    labelCols: {
      type: Number,
      default: 3
    },
    text: {
      type: String,
      default: null
    }
  },
  computed: {
    inputValue: {
      get () {
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    }
  }
}
</script>
