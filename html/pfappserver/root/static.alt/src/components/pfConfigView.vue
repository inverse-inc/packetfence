<template>
  <b-form @submit.prevent="(isNew || isClone) ? create($event) : save($event)" class="pf-config-view">
    <b-card no-body v-bind="$attrs" :class="cardClass">
      <b-card-header>
        <slot name="header">
          <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
          <h4 class="mb-0">
            <span>{{ $t('Configuration Template') }}</span>
          </h4>
        </slot>
      </b-card-header>
      <b-tabs v-if="view[0].tab || view.length > 1" v-model="tabIndex" :key="tabKey" card>
        <template v-for="(tab, t) in view">
          <b-tab v-if="!('if' in tab) || tab.if" :key="t"
            :disabled="tab.disabled"
            :title-link-class="{ 'text-danger': getTabErrorCount(t) > 0 }"
            :title="tab.tab"
            no-body
          ></b-tab>
        </template>
        <template v-slot:tabs-end>
          <slot name="tabs-end" />
        </template>
      </b-tabs>
      <template v-for="(tab, t) in view">
        <div class="card-body" v-if="tab.rows" v-show="t === tabIndex" :key="t">
          <template v-for="row in tab.rows">
            <b-form-group v-if="!('if' in row) || row.if" :key="row.key"
              :label-cols="('label' in row && row.cols) ? labelCols : 0"
              :label="row.label"
              :label-size="row.labelSize"
              :label-class="[(row.label && row.cols) ? '' : 'text-left', (row.cols) ? '' : 'offset-sm-3']"
              class="input-element" :class="{ 'mb-0': !row.label, 'pt-3': !row.cols }"
            >
<!--
          ^^^    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
-->
              <b-input-group align-v="start">
                <template v-for="col in row.cols">
                  <span v-if="col.text" :key="col.index" class="d-inline py-2" :class="col.class">{{ col.text }}</span>
                  <component v-else-if="!('if' in col) || col.if"
                    v-bind="col.attrs"
                    v-on="kebabCaseListeners(col.listeners)"
                    :formStoreName="formStoreName"
                    :formNamespace="col.namespace"
                    :key="col.namespace"
                    :is="col.component || defaultComponent"
                    :is-loading="isLoading"
                    :class="getClass(row, col)"
                    :disabled="(col.attrs && col.attrs.disabled) || disabled"
                    v-once
                  ></component>
                </template>
              </b-input-group>
              <b-form-text v-if="row.text" v-html="row.text"></b-form-text>
            </b-form-group>
          </template>
        </div>
      </template>
      <slot name="footer">
        <b-card-footer>
          <pf-button-save :disabled="invalidForm" :is-loading="isLoading">{{ isNew? $t('Create') : $t('Save') }}</pf-button-save>
          <pf-button-delete v-show="isDeletable" class="ml-1" :disabled="isLoading" :confirm="$t('Delete Config?')" @on-delete="remove($event)"/>
        </b-card-footer>
      </slot>
    </b-card>
  </b-form>
</template>

<script>
import uuidv4 from 'uuid/v4'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfFormInput from '@/components/pfFormInput'
import { createDebouncer } from 'promised-debounce'

export default {
  name: 'pfConfigView',
  components: {
    pfButtonSave,
    pfButtonDelete
  },
  props: {
    formStoreName: {
      type: String,
      required: true
    },
    view: {
      type: Object,
      required: true
    },
    isLoading: {
      type: Boolean
    },
    isNew: {
      type: Boolean
    },
    isClone: {
      type: Boolean
    },
    initialTabIndex: {
      type: Number,
      default: 0
    },
    disabled: {
      type: Boolean,
      default: false
    },
    cardClass: {
      type: String
    },
    labelCols: {
      type: Number,
      default: 3
    }
  },
  data () {
    return {
      tabKey: uuidv4(), // control tabs DOM rendering
      tabIndex: this.initialTabIndex,
      defaultComponent: pfFormInput
    }
  },
  computed: {
    form () {
      return this.$store.getters[`${this.formStoreName}/$form`]
    },
    invalidForm () {
      return this.$store.getters[`${this.formStoreName}/$formInvalid`]
    },
    isDeletable () {
      const { form: { not_deletable: notDeletable = false } = {} } = this
      if (this.isNew || this.isClone || notDeletable) {
        return false
      }
      return true
    }
  },
  methods: {
    close (event) {
      this.$emit('close', event)
    },
    create (event) {
      this.$emit('create', event)
    },
    save (event) {
      this.$emit('save', event)
    },
    remove (event) {
      this.$emit('remove', event)
    },
    getClass (row, col) {
      let c = ['px-0'] // always remove padding
      const { attrs: { ['class']: classDefinition } = {} } = col
      if (classDefinition) { // if class is defined
        c.push(classDefinition) // use manual definition
      } else if (row.cols.length === 1) { // else if row is singular
        c.push('col-sm-12') // use entire width
      }
      return c.join(' ')
    },
    getTabErrorCount (tabIndex) {
      return this.view[tabIndex].fields.reduce((tabCount, tab) => {
        if (!('fields' in tab)) return tabCount // ignore labels
        return tab.rows.reduce((rowCount, row) => {
/* TODO
          if (row.key in this.vuelidate && this.vuelidate[row.key].$anyError) {
            rowCount++
          }
*/
          return fieldCount
        }, tabCount)
      }, 0)
    },
    kebabCaseListeners (listeners) {
      if (listeners) {
        let kebabedListeners = {}
        Object.keys(listeners).forEach(key => {
          let kebabKey = ''
          key.split('').forEach((char, index) => {
            if (index > 0 && char === char.toUpperCase()) {
              kebabKey += '-' + char.toLowerCase()
            } else {
              kebabKey += char
            }
          })
          kebabedListeners[kebabKey] = listeners[key]
        })
        return kebabedListeners
      }
    }
  },
  mounted () {
    this.$store.commit('session/FORM_OK')
  }
}
</script>

<style lang="scss">
.pf-config-view {
  .input-group > span {
    display: flex;
    justify-content: center;
    align-items: center;
  }
}
</style>
