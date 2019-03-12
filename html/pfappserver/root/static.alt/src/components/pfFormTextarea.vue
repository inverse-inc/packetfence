<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()" :class="{ 'mb-0': !columnLabel }">
    <b-input-group v-if="placeholder && placeholderHtml" v-html="getPlaceholderHtml" class="mb-1" style="display: block"></b-input-group>
    <b-form-textarea
      ref="input"
      v-model="inputValue"
      v-bind="$attrs"
      :state="isValid()"
      :placeholder="filteredPlaceholder"
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
  name: 'pf-form-textarea',
  mixins: [
    pfMixinValidation
  ],
  props: {
    value: {
      default: null
    },
    columnLabel: {
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
    },
    placeholder: {
      type: String,
      default: null
    },
    placeholderHtml: {
      type: Boolean,
      default: false
    },
    labelHtml: {
      type: String,
      default: 'Default'
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
    },
    filteredPlaceholder () {
      // filter placeholder if placeholderHtml is enabled, using alternative layout
      return (this.placeholderHtml) ? null : this.placeholder
    },
    getPlaceholderHtml () {
      let html = []
      html.push('<div class="border border-light rounded bg-light p-2 text-white">')
      html.push(`<strong class="mr-1 text-dark">${this.labelHtml}:</strong> `)
      this.placeholder.split(',').forEach(item => {
        html.push(`<span class="badge badge-info mr-1">${item}</span> `)
      })
      html.push('</div>')
      return html.join('')
    }
  }
}
</script>
