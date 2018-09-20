<template>
  <b-form-group horizontal :label-cols="(label) ? labelCols : 0" :label="$t(label)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()">
    <b-form-select 
      v-model="inputValue" 
      :id="id"
      :name="name"
      :disabled="disabled"
      :required="required"
      :size="size"
      :state="isValid()"
      :plain="plain"
      :options="options"
      :value-field="valueField"
      :text-field="textField"
      :disabled-field="disabledField"
      :multiple="multiple"
      :select-size="selectSize"
      @input.native="validate()"
      @keyup.native="onChange($event)"
      @change.native="onChange($event)"
    ></b-form-select>
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
    labelCols: {
      type: Number,
      default: 3
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
    plain: {
      type: Boolean,
      default: false
    },
    options: {
      type: [Array, Object],
      default: null
    },
    valueField: {
      type: String,
      default: 'value'
    },
    textField: {
      type: String,
      default: 'text'
    },
    disabledField: {
      type: String,
      default: 'disabled'
    },
    multiple: {
      type: Boolean,
      default: false
    },
    selectSize: {
      type: Number,
      default: 0
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
