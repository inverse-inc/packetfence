<template>
  <b-row class="pf-field-person-openid mx-0 mb-1 px-0" align-v="center" no-gutters
    v-on="forwardListeners"
  >
    <b-col v-if="$slots.prepend" sm="1" align-self="start" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col :sm="($slots.prepend && $slots.append) ? 4 : (($slots.prepend || $slots.append) ? 5 : 6)" align-self="start">

      <pf-form-chosen ref="person_field"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.person_field`"
        v-on="forwardListeners"
        label="text"
        track-by="value"
        :placeholder="$t('Choose User field')"
        :options="options"
        :disabled="disabled"
        class="mr-1"
        collapse-object
      />

    </b-col>
    <b-col sm="6" align-self="start" class="pl-1">

      <pf-form-input ref="openid_field"
        :form-store-name="formStoreName"
        :form-namespace="`${formNamespace}.openid_field`"
        :placeholder="$t('Enter OpenID field')"
        :disabled="disabled"
      />

    </b-col>
    <b-col v-if="$slots.append" sm="1" align-self="start" class="text-center col-form-label">
      <slot name="append"></slot>
    </b-col>
  </b-row>
</template>

<script>
/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-field-person-openid',
  components: {
    pfFormChosen,
    pfFormInput
  },
  mixins: [
    pfMixinForm
  ],
  props: {
    value: {
      type: Object,
      default: () => { return { person_field: null, openid_field: null } }
    },
    options: {
      type: Array,
      default: () => { return [] }
    },
    disabled: {
      type: Boolean,
      default: false
    },
    drag: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      default: { person_field: null, openid_field: null } // default value
    }
  },
  computed: {
    inputValue: {
      get () {
        return { ...this.default, ...this.formStoreValue } // use FormStore
      },
      set (newValue = null) {
        this.formStoreValue = newValue // use FormStore
      }
    },
    localPerson () {
      return this.inputValue.person_field
    },
    localOpenid () {
      return this.inputValue.openid_field
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  },
  methods: {
    focus () {
      if (this.localPerson) {
        this.focusOpenidField()
      } else {
        this.focusPerson()
      }
    },
    focusPerson () {
      const { $refs: { person_field: { focus = () => {} } = {} } = {} } = this
      focus()
    },
    focusOpenidField () {
      const { $refs: { openid_field: { focus = () => {} } = {} } = {} } = this
      focus()
    }
  },
  watch: {
    localPerson: {
      handler: function () {
        if (!this.drag) { // don't focus when being dragged
          this.$set(this.formStoreValue, 'openid_field', null) // clear value
          this.$nextTick(() => {
            this.focus()
          })
        }
      }
    }
  }
}
</script>
