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
      <b-tabs v-if="view && (view[0].tab || view.length > 1)" v-model="tabIndex" :key="tabKey" card>
        <template v-for="(tab, t) in conditionalView">
          <b-tab :key="t"
            :disabled="tab.disabled || disabled"
            :title-link-class="{ 'is-invalid': tabErrorCount[t] > 0 }"
            :title="tab.tab"
            no-body
          />
        </template>
        <template v-slot:tabs-end>
          <slot name="tabs-end" />
        </template>
      </b-tabs>
      <template v-for="(tab, t) in conditionalView">
        <div class="card-body" v-show="t === tabIndex" :key="t">
          <template v-for="row in tab.rows">
            <b-form-group :key="row.key"
              :label-cols="('label' in row && row.cols) ? labelCols : 0"
              :label="row.label"
              :label-size="row.labelSize"
              :label-class="[(row.label && row.cols) ? '' : 'text-left', (row.cols) ? '' : 'offset-sm-3']"
              class="input-element" :class="{ 'mb-0': !row.label, 'pt-3': !row.cols }"
            >
              <b-input-group align-v="start">
                <template v-for="col in row.cols">
                  <span v-if="col.text" :key="col.index" class="d-inline py-2" :class="col.class">{{ col.text }}</span>
                  <component v-show="(!('if' in col) || col.if) && col.component"
                    v-bind="col.attrs"
                    v-on="kebabCaseListeners(col.listeners)"
                    :form-store-name="formStoreName"
                    :form-namespace="`${(formNamespace) ? `${formNamespace}.` : ''}${col.namespace}`"
                    :key="col.namespace"
                    :is="col.component"
                    :is-loading="isLoading"
                    :class="getClass(row, col)"
                    :disabled="(col.attrs && col.attrs.disabled) || disabled"
                  ><span v-if="col.html">{{ col.html }}</span></component>
                </template>
              </b-input-group>
              <b-form-text v-if="row.text" v-html="row.text"></b-form-text>
            </b-form-group>
          </template>
        </div>
      </template>
      <slot name="footer" />
    </b-card>
  </b-form>
</template>

<script>
import uuidv4 from 'uuid/v4'
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
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
    formNamespace: {
      type: String,
      default: null
    },
    view: {
      type: Array,
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
      tabErrorCountCache: false
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
      const { isNew, isClone, form: { not_deletable: notDeletable = false } = {} } = this
      if (isNew || isClone || notDeletable) {
        return false
      }
      return true
    },
    tabErrorCount: {
      get () {
        if (!this.tabErrorCountDebouncer) {
          // eslint-disable-next-line vue/no-side-effects-in-computed-properties
          this.tabErrorCountDebouncer = createDebouncer()
          // eslint-disable-next-line vue/no-side-effects-in-computed-properties
          this.tabErrorCountCache = this.conditionalView.map(() => 0)
        }
        this.tabErrorCountDebouncer({
          handler: () => {
            this.tabErrorCountCache = this.conditionalView.map(view => {
              return view.rows.reduce((rowCount, row) => {
                if (!('cols' in row)) return rowCount
                return row.cols.reduce((colCount, col) => {
                  if (!('namespace' in col)) return colCount
                  const { $invalid = false, $pending = false } = this.$store.getters[`${this.formStoreName}/$stateNS`](col.namespace)
                  if ($invalid && !$pending) colCount++
                  return colCount
                }, rowCount)
              }, 0)
            })
          },
          time: 1000 // 1 second
        })
        return this.tabErrorCountCache
      }
    },
    conditionalView () {
      return this.view.map(tab => {
        return {
          ...tab,
          rows: tab.rows.map(row => {
            return {
              ...row,
              cols: (row.cols || []).filter(col => (!('if' in col) || col.if))
            }
          }).filter(row => (!('if' in row) || row.if) && row.cols && row.cols.length > 0)
        }
      }).filter(tab => (!('if' in tab) || tab.if) && tab.rows && tab.rows.length > 0)
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
      const { attrs: { 'class': classDefinition = false } = {} } = col
      let c = []
      if (classDefinition) { // class is defined
        c.push(classDefinition) // use manual definition
      }
      else if (row.cols.length === 1) { // else if row is singular
        c.push('px-0', 'col-sm-12') // remove padding, use entire width
      }
      else if (row.cols.findIndex(_col => _col.namespace === col.namespace) < row.cols.length - 1) { // else col has subsequent siblings
        c.push('pl-0', 'pr-2') // remove left padding, add right padding
      }
      return c.join(' ')
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
    // When tabs are defined, make sure to show the initial tab once the form has finished loading
    // See https://github.com/inverse-inc/packetfence/issues/5721
    if (this.view && (this.view[0].tab || this.view.length > 1)) {
      let unwatch = this.$watch('isLoading', function () {
        if (this.tabIndex < 0)
          this.tabIndex = this.initialTabIndex
        unwatch()
      })
    }
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
  .nav-tabs .nav-link {
    transition: 300ms ease all;
  }
  .nav-tabs .nav-link.is-invalid {
    color: $form-feedback-invalid-color;
  }
  .nav-tabs .nav-link.active.is-invalid {
    border-color: $form-feedback-invalid-color;
  }
}
</style>
