<template>
  <b-form-group horizontal label-cols="3" :label="$t(label)"
    :state="isValid()" :invalid-feedback="$t(getInvalidFeedback())">
    <b-form-input 
      v-model="inputValue"
      :id="id"
      :name="name"
      :disabled="disabled"
      :required="required"
      :size="size"
      :state="isValid()"
      :type="type"
      :readonly="readonly"
      :plaintext="plaintext"
      :autocomplete="autocomplete"
      :placeholder="placeholder"
      :formatter="formatter"
      :lazy-formatter="lazyFormatter"
      @input.native="validate()"
      @keyup.native="onChange($event)"
      @change.native="onChange($event)
    "></b-form-input>
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
    text: {
      type: String,
      default: null
    },
    id: {
      type: String,
      default: null
    },
    name: {
      type: String,
      default: null
    },
    disabled: {
      type: Boolean,
      default: null
    },
    required: {
      type: Boolean,
      default: false
    },
    size: {
      type: String,
      default: null
    },
    type: {
      type: String,
      default: 'text'
    },
    readonly: {
      type: Boolean,
      default: false
    },
    plaintext: {
      type: Boolean,
      default: false
    },
    autocomplete: {
      type: String,
      default: null
    },
    placeholder: { // Warning: This prop is not automatically translated.
      type: String,
      default: null
    },
    formatter: {
      type: Function
    },
    lazyFormatter: {
      type: Boolean,
      default: false
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
