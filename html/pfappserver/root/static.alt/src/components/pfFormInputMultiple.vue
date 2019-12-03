<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="isValid()"
    class="pf-form-chosen pf-form-input-multiple" :class="{ 'mb-0': !columnLabel, 'is-focus': hasFocus, 'is-empty': !value, 'is-disabled': disabled }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!getInvalidFeedback()"></icon> {{ feedbackState }}
    </template>
    <b-input-group>
      <multiselect
        v-model="inputValue"
        v-bind="$attrs"
        v-on="forwardListeners"
        ref="input"
        track-by="value"
        label="text"
        :disabled="disabled"
        :state="isValid()"
        :multiple="true"
        :options="options"
        :taggable="true"
        :placeholder="proxyPlaceholder"
        :tag-placeholder="proxyTagPlaceholder"
        @tag="addTag"
        @input.native="validate()"
        @open="onFocus"
        @close="onBlur"
      ></multiselect>
      <b-input-group-append v-if="readonly || disabled">
        <b-button v-if="readonly || disabled" class="input-group-text" tabindex="-1" disabled><icon name="lock"></icon></b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-input-multiple',
  mixins: [
    pfMixinValidation
  ],
  components: {
    Multiselect
  },
  props: {
    value: {
      default: null
    },
    columnLabel: {
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
    disabled: {
      type: Boolean,
      default: false
    },
    readonly: {
      type: Boolean,
      default: false
    },
    separator: {
      type: String,
      default: ','
    },
    placeholder: {
      type: String,
      default: null
    },
    tagPlaceholder: {
      type: String,
      default: null
    }
  },
  data () {
    return {
      hasFocus: false
    }
  },
  computed: {
    inputValue: {
      get () {
        let inputValue = ((this.value)
          ? this.value
            .split(this.separator.trim())
            .filter(value => value)
            .map(value => { return { text: value.trim(), value: value.trim() } })
          : []
        )
        return inputValue
      },
      set (newValue) {
        this.$emit('input', newValue.map(value => value.value).filter(value => value).join(this.separator) || null)
      }
    },
    options () {
      return this.inputValue
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    proxyPlaceholder () {
      return (this.hasFocus)
        ? this.placeholder || this.$i18n.t('Enter a new value')
        : '' // hide placeholder when not in focus
    },
    proxyTagPlaceholder () {
      return this.tagPlaceholder || this.$i18n.t('Click to add value')
    }
  },
  methods: {
    onFocus () {
      this.hasFocus = true
    },
    onBlur () {
      this.hasFocus = false
    },
    focus () {
      this.$refs.input.focus()
    },
    addTag (newTag) {
      this.$set(this, 'inputValue', [ ...this.inputValue, ...[{ text: newTag, value: newTag }] ])
    }
  }
}
</script>

<style lang="scss">
.pf-form-input-multiple {
  .multiselect__tag {
    overflow: unset;
  }
  .multiselect__input,
  .multiselect__single {
    padding: $input-padding-y 0;
  }
  &.is-empty .multiselect__input,
  &.is-empty .multiselect__single {
    padding: 0;
  }
}
</style>
