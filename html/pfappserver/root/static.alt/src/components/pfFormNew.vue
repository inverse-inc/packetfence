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
        <b-input-group class="p-3">
          <b-calendar
            v-model="inputValue"
            :locale="$i18n.locale"
            @context="onDateContext"
          ></b-calendar>
        </b-input-group>
      </b-popover>

<pre>{{ JSON.stringify({formatHasDate,dateFormat,dateValue,formatHasTime,timeFormat,timeValue,focus}, null, 2) }}</pre>


      <b-input-group-append>
        <b-button class="input-group-text" @click.stop.prevent="inputElement.focus()" tabindex="-1">
          <icon :name="formatHasDate ? 'calendar-alt' : 'clock'" variant="light"></icon>
        </b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-show="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinForm from '@/components/pfMixinForm'

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
    dateFormat () {
      let dateFormat = this.format.replace(/[HmsXA]+/g, '')
      let min = dateFormat.length - 1
      let max = 0
      for (let i=0; i < dateFormat.length; i++) {
        if ('YMDd'.includes(dateFormat[i])) {
          min = Math.min(min, i)
          max = Math.max(max, i)
        }
      }
      return dateFormat.slice(min, max + 1)
    },
    dateValue () {
      return this.inputValue
    },
    timeFormat () {
      let timeFormat = this.format.replace(/[YMDd]+/g, '')
      let min = timeFormat.length - 1
      let max = 0
      for (let i=0; i < timeFormat.length; i++) {
        if ('HmsXA'.includes(timeFormat[i])) {
          min = Math.min(min, i)
          max = Math.max(max, i)
        }
      }
      return timeFormat.slice(min, max + 1)
    },
    timeValue () {
      return this.inputValue
    },
    formatHasDate () {
      //return /[YyFMmndJjlD]+/.test(this.format)
      return /[YMDd]+/.test(this.format)
    },
    formatHasTime () {
      //return /[HhGiSsK]+/.test(this.format)
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
      }, 100)
    },
    onDateContext (context) {
      if (this.onBlurInputTimeout) { // don't blur
        clearTimeout(this.onBlurInputTimeout)
      }
      if (this.focus) {
        this.inputElement.focus() // refocus
      }
      const { selectedDate } = context
      console.log('date', {selectedDate, context})
    },
    onTimeContext (context) {
      console.log('time', {context})
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
