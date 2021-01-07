<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputState"
    class="pf-form-chosen pf-form-input-multiple" :class="{ 'mb-0': !columnLabel, 'is-focus': hasFocus, 'is-empty': !inputValue, 'is-disabled': disabled }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!inputInvalidFeedback"></icon> {{ inputInvalidFeedback }}
    </template>
    <b-input-group>
      <multiselect ref="multiselect"
        v-model="multiselectValue"
        v-bind="$attrs"
        track-by="value"
        label="text"
        :disabled="disabled"
        :state="inputState"
        :multiple="true"
        :options="multiselectValue"
        :taggable="true"
        :placeholder="multiselectPlaceholder"
        :tag-placeholder="multiselectTagPlaceholder"
        @tag="addTag"
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
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-form-input-multiple',
  mixins: [
    pfMixinForm
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
        if (this.formStoreName) {
          return this.formStoreValue // use FormStore
        } else {
          return this.value // use native (v-model)
        }
      },
      set (newValue) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    multiselectValue: {
      get () {
        let inputValue = (this.inputValue)
          ? this.inputValue
            .split(this.separator.trim())
            .filter(value => value)
            .map(value => { return { text: value.trim(), value: value.trim() } })
          : []
        return inputValue
      },
      set (newValue) {
        this.inputValue = newValue.map(value => value.value).filter(value => value).join(this.separator) || null
      }
    },
    multiselectPlaceholder () {
      return (this.hasFocus)
        ? this.placeholder || this.$i18n.t('Enter a new value')
        : '' // hide placeholder when not in focus
    },
    multiselectTagPlaceholder () {
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
      const { $refs: { multiselect: { $el } = {} } = {} } = this
      $el.focus()
    },
    addTag (newTag) {
      this.$set(this, 'multiselectValue', [ ...this.multiselectValue, ...[{ text: newTag, value: newTag }] ])
      this.focus()
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
