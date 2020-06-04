<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="columnLabel" :state="inputState"
    class="pf-form-input" :class="{ 'mb-0': !columnLabel }">
    <template v-slot:invalid-feedback>
      {{ inputInvalidFeedback }}
    </template>
    <b-input-group>
      <b-input-group-prepend v-if="prependText">
        <div class="input-group-text">
          {{ prependText }}
        </div>
      </b-input-group-prepend>
      <b-form-input ref="inputElement"
        :id="`input-${formNamespace}`"
        v-model="inputValue"
        type="text"
        :placeholder="placeholder || format"
        autocomplete="off"
        @keydown="onFocusInput($event)"
        @click="onFocusInput($event)"
        @focus="onFocusInput($event)"
        @blur="onBlurInput($event)"
      ></b-form-input>
      <b-popover :show.sync="focus"
        custom-class="popover-w-100"
        placement="top"
        triggers="manual"
        :target="`input-${formNamespace}`"
      >
        <template v-slot:title>
          <b-row class="small">
            <b-col cols="auto">
              {{ (formatHasDate) ? $t('Choose Date') : $t('Choose Time') }}
            </b-col>
            <b-col cols="auto" class="ml-auto text-secondary">
              {{ format }}
            </b-col>
          </b-row>
        </template>
        <b-row class="text-center" no-gutters v-if="formatHasDate">
          <b-col cols="12" class="text-center p-2" :class="{ 'pb-3': formatHasTime }"
            v-on:click="onEventVacuum($event)"
            v-on:mousedown="onEventVacuum($event)"
          >
            <b-calendar
              v-model="dateValue"
              class="align-self-center"
              :locale="$i18n.locale"
              @selected="onDateSelected"
              label-help=""
              hide-header
              block
            ></b-calendar>
          </b-col>
        </b-row>
        <b-row class="text-center" no-gutters v-if="formatHasTime">
          <b-col cols="12" class="text-center p-2" :class="{ 'pt-3 border-top': formatHasDate }"
            v-on:click="onEventVacuum($event)"
            v-on:mousedown="onEventVacuum($event)"
          >
            <b-time
              v-model="timeValue"
              class="align-self-center"
              :locale="$i18n.locale"
              @context="onTimeContext"
              show-seconds hide-header
            ></b-time>
          </b-col>
        </b-row>
      </b-popover>
      <b-input-group-append>
        <b-button class="input-group-text" @click.stop.prevent="onToggleFocus($event)" tabindex="-1">
          <icon :name="formatHasDate ? 'calendar-alt' : 'clock'" variant="light"></icon>
        </b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-show="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinForm from '@/components/pfMixinForm'
import {
  parse,
  format,
  getHours,
  getMinutes,
  getSeconds,
  setHours,
  setMinutes,
  setSeconds,

  isValid,
  addYears,
  addQuarters,
  addMonths,
  addWeeks,
  addDays,
  addHours,
  addMinutes,
  addSeconds,
  addMilliseconds
} from 'date-fns'

export default {
  name: 'pf-form-boolean',
  mixins: [
    pfMixinForm
  ],
  data () {
    return {
      focus: false
    }
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
    prependText: {
      type: String
    },
    //:config="{datetimeFormat: schema.password.expiration.datetimeFormat}"
/*
src/components/pfFieldTypeMatch.vue
43:      <pf-form-datetime ref="match" v-else-if="isComponentType([componentType.DATETIME])"
44-        :form-store-name="formStoreName"
45-        :form-namespace="`${formNamespace}.match`"
46-        :config="{useCurrent: true, datetimeFormat: 'YYYY-MM-DD HH:mm:ss'}"
47-        :disabled="disabled"
48-        :moments="matchMoments"



src/components/pfFieldAttributeOperatorValue.vue
45:      <pf-form-datetime ref="value" v-else-if="isComponentType([componentType.TIME])"
46-        :form-store-name="formStoreName"
47-        :form-namespace="`${formNamespace}.value`"
48-        :config="{useCurrent: false, datetimeFormat: 'HH:mm'}"
49-        :disabled="disabled"
50-        placeholder="HH:mm"
51:      ></pf-form-datetime>


src/components/pfCSVImport.vue
169:                <pf-form-datetime v-else-if="isComponentType([componentType.DATE], staticMap)"
170-                  v-model="staticMap.value"
171-                  :ref="staticMap.key"
172-                  :config="{format: 'YYYY-MM-DD'}"
173-                  :disabled="isDisabled"
174-                  :state="getStaticMappingState(index)" :invalid-feedback="getStaticMappingInvalidFeedback(index)"
175:                ></pf-form-datetime>
176-
177:                <pf-form-datetime v-else-if="isComponentType([componentType.DATETIME], staticMap)"
178-                  v-model="staticMap.value"
179-                  :ref="staticMap.key"
180-                  :config="{format: 'YYYY-MM-DD HH:mm:ss'}"
181-                  :disabled="isDisabled"
182-                  :state="getStaticMappingState(index)" :invalid-feedback="getStaticMappingInvalidFeedback(index)"
183:                ></pf-form-datetime>

*/
    config: {
      type: Object,
      default: () => ({})
    },
/*
src/views/Reports/_components/DynamicReportChart.vue
46:            <pf-form-datetime v-model="datetimeStart" :max="maxStartDatetime" :prepend-text="$t('Start')" class="mr-3" :disabled="isLoadingReport"></pf-form-datetime>
47:            <pf-form-datetime v-model="datetimeEnd" :min="minEndDatetime" :prepend-text="$t('End')" class="mr-3" :disabled="isLoadingReport"></pf-form-datetime>
*/
    min: {
      type: String
    },
    max: {
      type: String
    },
    //  :config="{useCurrent: true}" :moments="['-1 hours', '-1 days', '-1 weeks', '-1 months', '-1 quarters', '-1 years']"
/*
src/views/Nodes/_components/NodeView.vue
31:              <pf-form-datetime :column-label="$t('Unregistration')"
32-                :form-store-name="formStoreName" form-namespace="unregdate"
33-                :moments="['1 hours', '1 days', '1 weeks', '1 months', '1 quarters', '1 years']"
34-              />

src/views/Users/_components/UsersImport.vue
38:                      <pf-form-datetime
39-                        :form-store-name="formStoreName" form-namespace="valid_from"
40-                        :min="(new Date().setHours(0,0,0,0))"
41-                        :config="{datetimeFormat: schema.password.valid_from.datetimeFormat}"
42-                      />
43-                    </b-col>
--
46:                      <pf-form-datetime
47-                        :form-store-name="formStoreName" form-namespace="expiration"
48-                        :min="(new Date().setHours(0,0,0,0))"
49-                        :config="{datetimeFormat: schema.password.expiration.datetimeFormat}"
50-                      />
51-                    </b-col>
*/
    moments: {
      type: Array,
      default: () => []
    },

// NEW!
    format: {
      type: String,
      default: 'YYYY-MM-DD HH:mm:ss'
    },
    useCurrent: {
      type: Boolean,
      default: false
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
    inputElement () {
      const { $refs: { inputElement } = {} } = this
      return inputElement
    },
    dateValue: {
      get () {
        // b-calendar expects Date()
        if (this.inputValue) {
          let dateValue = parse(this.inputValue, this.format)
          dateValue = setHours(dateValue, 0)
          dateValue = setMinutes(dateValue, 0)
          dateValue = setSeconds(dateValue, 0)
          return dateValue
        }
        else {
          return (new Date(new Date().setHours(0, 0, 0, 0)))
        }
      }
    },
    timeValue: {
      get () {
        // b-time expects String w/ format 'HH:mm:ss'
        if (this.inputValue) {
          let inputValue
          if (this.formatHasDate) {
            inputValue = parse(this.inputValue, this.format)
          }
          else {
            // date-fns does not parse only a time format (eg: 'HH:mm:ss'),
            //  workaround by adding a known prefix
            inputValue = parse(`1973-01-01 ${this.inputValue}`, `YYYY-MM-DD ${this.format}`)
          }

          let formattedValue = format(inputValue, 'HH:mm:ss')
          if (this.inputValue.includes(formattedValue)) {
            return formattedValue
          }
        }
        return null
      }
    },
    formatHasDate () {
      return /[YMDd]+/.test(this.format)
    },
    formatHasTime () {
      return /[HmsXA]+/.test(this.format)
    }
  },
  methods: {
    onFocusInput (event) {
      if (this.onBlurInputTimeout) {
        clearTimeout(this.onBlurInputTimeout)
      }
      this.focus = true
    },
    onBlurInput (event) {
      if (this.onBlurInputTimeout) {
        clearTimeout(this.onBlurInputTimeout)
      }
      this.onBlurInputTimeout = setTimeout(() => { // wait for b-calendar context
        this.focus = false
      }, 300)
    },
    onEventVacuum (event) {
      // popover component event, focus was stolen, defer onBlur
      if (this.onBlurInputTimeout) {
        clearTimeout(this.onBlurInputTimeout)
        setTimeout(() => {
          clearTimeout(this.onBlurInputTimeout)
        }, 300)
      }
      if (this.focus) {
        this.inputElement.focus() // refocus
      }
    },
    onToggleFocus (event) {
      if (this.focus) {
        this.inputElement.blur()
      }
      else {
        this.inputElement.focus()
      }
    },
    onDateSelected (date) {
      let selectedDate = parse(date, 'YYYY-MM-DD') // b-calendar uses 'YYYY-MM-DD' format
      if (selectedDate) {
        if (this.inputValue && this.formatHasTime) {
          let parsedInputValue = parse(this.inputValue, this.format)
          selectedDate = addHours(selectedDate, getHours(parsedInputValue))
          selectedDate = addMinutes(selectedDate, getMinutes(parsedInputValue))
          selectedDate = addSeconds(selectedDate, getSeconds(parsedInputValue))
        }
        this.inputValue = format(selectedDate, this.format)
      }
    },
    onTimeContext (context) {
      if (this.onBlurInputTimeout) { // don't blur input
        clearTimeout(this.onBlurInputTimeout)
      }
      if (this.focus) {
        this.inputElement.focus() // refocus
      }
      let selectedDate
      const { hours, minutes, seconds } = context
      if (hours !== null || minutes !== null || seconds !== null) {
        if (this.inputValue && this.formatHasDate) {
          selectedDate = parse(this.inputValue, this.format)
          selectedDate = setHours(selectedDate, hours || 0)
          selectedDate = setMinutes(selectedDate, minutes || 0)
          selectedDate = setSeconds(selectedDate, seconds || 0)
        }
        else {
          selectedDate = (new Date(new Date().setHours(hours || 0, minutes || 0, seconds || 0, 0)))
        }
        this.inputValue = format(selectedDate, this.format)
      }
    }
  }
}
</script>

<style lang="scss">
  .pf-form-new {

  }
  .popover-w-100 {
      max-width: 100%; /* Max Width of the popover (depending on the container!) */
  }
</style>
