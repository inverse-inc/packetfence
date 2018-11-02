<template>
  <b-form @submit.prevent="isNew? create() : save()">
    <b-card no-body>
      <slot name="header">
        <b-card-header>
          <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
          <h4 class="mb-0">
            <span>{{ $t('Configuration Template') }}</span>
          </h4>
        </b-card-header>
      </slot>
      <div class="card-body" v-if="form.fields">
        <b-form-group v-for="field in form.fields" :key="field.key" v-if="!('if' in field) || field.if"
          :label-cols="(field.label) ? form.labelCols : 0" :label="field.label"
          :state="isValid()" :invalid-feedback="getInvalidFeedback()"
          class="input-element" :class="{ 'mb-0': !field.label }"
          horizontal
        >
          <b-input-group>
            <component :is="field.component || defaultComponent"
              v-model="field.model"
              v-bind="field.attrs"
              :validation="validation[field.key]"
              class="col-sm-12 px-0"
            ></component>
            <b-input-group-append v-if="field.attrs && field.attrs.readonly">
              <b-button class="input-group-text"><icon name="lock"></icon></b-button>
            </b-input-group-append>
          </b-input-group>
          <b-form-text v-if="field.text" v-t="field.text"></b-form-text>
        </b-form-group>
      </div>
      <slot name="footer">
        <b-card-footer @mouseenter="validation.$touch()">
          <pf-button-save :disabled="invalidForm" :isLoading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
          <pf-button-delete v-if="!isNew" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Config?')" @on-delete="remove()"/>
        </b-card-footer>
      </slot>
    </b-card>
  </b-form>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormInput from '@/components/pfFormInput'
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pfConfigView',
  components: {
    pfButtonSave,
    pfButtonDelete,
    pfFormInput
  },
  mixins: [
    pfMixinValidation
  ],
  props: {
    form: {
      type: Object
    },
    validation: {
      type: Object
    },
    isLoading: {
      type: Boolean
    }
  },
  computed: {
    isNew () {
      console.log('isNew', this.form.fields, this.form.fields.filter(field => field.key === 'id').length === 0)
      return this.form.fields.filter(field => field.key === 'id').length === 0
    },
    defaultComponent () {
      return pfFormInput
    }
  },
  methods: {
    close () {
      this.$emit('close')
    },
    create () {
      this.$emit('create')
    },
    save () {
      this.$emit('save')
    },
    remove () {
      this.$emit('remove')
    },
    getValidations () {
      const eachFieldValue = {}
      if (this.form.fields.length > 0) {
        this.form.fields.forEach((field, index) => {
          eachFieldValue[field.key] = {}
          if ('validators' in field) { // has vuelidate validations
            eachFieldValue[field.key] = field.validators
          }
        })
        Object.freeze(eachFieldValue)
      }
      return eachFieldValue
    },
    emitExternalValidations () {
      // debounce to avoid emit storm,
      // delay to allow internal form field to update before building external validations
      if (this.emitExternalValidationsTimeout) clearTimeout(this.emitExternalValidationsTimeout)
      this.emitExternalValidationsTimeout = setTimeout(() => {
        this.$emit('validations', this.getValidations())
        if (this.validation && this.validation.$dirty) {
          this.$nextTick(() => {
            this.validation.$touch()
          })
        }
        this.$nextTick(() => {
          // force DOM update
          this.$forceUpdate()
        })
      }, 100)
    }
  },
  watch: {
    form: {
      handler: function (a, b) {
        this.emitExternalValidations()
      },
      deep: true
    }
  }
}
</script>
