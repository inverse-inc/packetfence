<template>
  <b-form-group horizontal label-cols="3" :label="$t(label)"
    :state="isValid()" :invalid-feedback="$t(getInvalidFeedback())">
    <b-form-input :type="type" :placeholder="placeholder" v-model="inputValue" @input.native="validate()" @keyup.native="onChange($event)" @change.native="onChange($event)" :state="isValid()"></b-form-input>
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
      type: String
    },
    type: {
      type: String,
      default: 'text'
    },
    placeholder: { // Warning: This prop is not automatically translated.
      type: String,
      default: null
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

