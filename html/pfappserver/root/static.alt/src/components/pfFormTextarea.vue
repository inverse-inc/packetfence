<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)" :state="inputState"
    class="pf-form-textarea" :class="{ 'mb-0': !columnLabel }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!inputInvalidFeedback"></icon> <span v-html="inputInvalidFeedback"></span>
    </template>
    <b-input-group v-if="placeholder && placeholderHtml" v-html="getPlaceholderHtml" class="mb-1 d-block"></b-input-group>
    <b-input-group>
      <b-form-textarea ref="input"
        v-model="inputValue"
        v-bind="$attrs"
        :state="inputState"
        :placeholder="filteredPlaceholder"
      ></b-form-textarea>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-form-textarea',
  mixins: [
    pfMixinForm
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
        if (this.formStoreName) {
          return this.formStoreValue // use FormStore
        } else {
          return this.value // use native (v-model)
        }
      },
      set (newValue = null) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    filteredPlaceholder () {
      // filter placeholder if placeholderHtml is enabled, using alternative layout
      return (this.placeholderHtml) ? null : this.placeholder
    },
    getPlaceholderHtml () {
      let html = []
      html.push('<div class="border border-gray rounded p-2">')
      html.push(`<h6 class="mr-1">${this.labelHtml}</h6> `)
      this.placeholder.split(/[,\n]/).forEach(item => {
        html.push(`<span class="badge badge-info mr-1">${item}</span> `)
      })
      html.push('</div>')
      return html.join('')
    }
  },
  methods: {
    focus () {
      this.$refs.input.focus()
    },
    select (start, end) {
      const { inputValue = '' } = this
      start = start || 0
      end = end || (inputValue||'').length
      this.$refs.input.select(start, end)
    }
  }
}
</script>
