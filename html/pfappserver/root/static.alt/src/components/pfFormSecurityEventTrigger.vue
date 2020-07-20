<template>
  <b-form-row :id="`security-event-trigger-row_${uuid}`"
    class="align-items-center security-event-trigger-row flex-nowrap text-center py-1">
    <b-badge class="or">{{ $t('OR') }}</b-badge>
    <b-col cols="1" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col cols="2">
      <b-link href="javascript:void(0)" :disabled="disabled" :id="`endpoint_${uuid}`" :class="{ 'text-danger': endpointInvalid }">
        <span v-for="(desc, index) in endpointDescription" :key="desc">
          {{ desc }} <b-badge variant="light" v-if="endpointDescription.length - index > 1">{{ $t('AND') }}</b-badge>
        </span>
      </b-link>
    </b-col>
    <b-col>
      <b-badge>{{ $t('AND') }}</b-badge>
    </b-col>
    <b-col cols="2">
      <b-link href="javascript:void(0)" :disabled="disabled" :id="`profiling_${uuid}`" :class="{ 'text-danger': profilingInvalid }">
        <span v-for="(desc, index) in profilingDescription" :key="desc">
          {{ desc }} <b-badge variant="light" v-if="profilingDescription.length - index > 1">{{ $t('AND') }}</b-badge>
        </span>
      </b-link>
    </b-col>
    <b-col>
      <b-badge>{{ $t('AND') }}</b-badge>
    </b-col>
    <b-col cols="2">
      <b-link href="javascript:void(0)" :disabled="disabled" :id="`usage_${uuid}`" :class="{ 'text-danger': usageInvalid }">{{ usageDescription }}</b-link>
    </b-col>
    <b-col>
      <b-badge>{{ $t('AND') }}</b-badge>
    </b-col>
    <b-col cols="2">
      <b-link href="javascript:void(0)" :disabled="disabled" :id="`event_${uuid}`" :class="{ 'text-danger': eventInvalid }">{{ eventDescription }}</b-link>
    </b-col>
    <b-col cols="1" class="col-form-label">
      <slot name="append"></slot>
    </b-col>
    <!-- Popover for each category -->
    <b-popover v-for="category of Object.values(triggerCategories)"
      triggers="click"
      placement="top"
      :key="category"
      v-model:show="popover[category]"
      :target="`${category}_${uuid}`"
      :container="`security-event-trigger-row_${uuid}`"
    >
      <div :ref="`${category}Popover`">
        <pf-config-view v-if="popover[category]"
          :form-store-name="formStoreName"
          :form-namespace="`${formNamespace}.${category}`"
          :view="view[category]"
          card-class="card-sm"
          border-variant="light"
        >
          <template v-slot:header>
            <b-button-close size="sm" @click="closePopover(category)" v-b-tooltip.hover.left.d300 :title="$t('Close')"><icon name="times"></icon></b-button-close>
            <h5 class="m-0" v-text="triggerCategoryTitles[category]"></h5>
          </template>
          <template v-slot:footer>
            <b-card-footer class="text-right" v-if="[triggerCategories.USAGE, triggerCategories.EVENT].includes(category)">
              <pf-button size="sm" variant="danger" class="mr-1" @click="removeCategory(category)">{{ $t('Delete') }}</pf-button>
            </b-card-footer>
          </template>
        </pf-config-view>
      </div>
    </b-popover>
  </b-form-row>
</template>

<script>
import apiCall from '@/utils/api'
import bytes from '@/utils/bytes'
import pfButton from '@/components/pfButton'
import pfConfigView from '@/components/pfConfigView'
import pfMixinForm from '@/components/pfMixinForm'
import uuidv4 from 'uuid/v4'

import {
  triggerCategories,
  triggerCategoryTitles,
  triggerFields,
  triggerDirections,
  triggerIntervals,
  triggerEndpointView,
  triggerProfilingView,
  triggerUsageView,
  triggerEventView
} from '@/views/Configuration/_config/securityEvent'

export default {
  name: 'pf-form-security-event-trigger',
  mixins: [
    pfMixinForm
  ],
  components: {
    pfButton,
    pfConfigView
  },
  props: {
    value: {
      default: null
    },
    meta: {
      type: Object,
      default: () => {}
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      triggerCategories, // ../_config/securityEvent
      triggerCategoryTitles, // ../_config/securityEvent
      popover: { endpoint: false, profiling: false, usage: false, event: false },
      uuid: uuidv4(), // unique id for multiple instances of this component
      lookupCache: {}
    }
  },
  computed: {
    endpointDescription () {
      const { endpoint: { conditions = [] } = {} } = this.formStoreValue || {}
      return conditions.filter(condition => {
        const { type, value } = condition || {}
        return (type && value)
      }).length > 0
        ? conditions.map(condition => {
          const { type, value } = condition || {}
          return `${triggerFields[type].text}: ${value}`
        })
        : [this.$i18n.t('No condition')]
    },
    endpointInvalid () {
      const state = this.$store.getters[`${this.formStoreName}/$stateNS`](`${this.formNamespace}.endpoint`)
      return state.$invalid && !state.$pending
    },
    profilingDescription () {
      const { profiling: { conditions = [] } = {} } = this.formStoreValue || {}
      return conditions.filter(condition => {
        const { type, value } = condition || {}
        return (type && value)
      }).length > 0
        ? conditions.map(condition => {
          const { type, value } = condition || {}
          let { lookupCache: { [type]: lookupType, [type]: { [value]: lookupValue } = {} } = {} } = this
          if (!lookupType) {
            this.$set(this.lookupCache, type, {})
          }
          if (!lookupValue) {
            this.$set(this.lookupCache, type, { value: `${triggerFields[type].text}: ${value}` }) // use default
            // perform lookup
            const { meta: { triggers: { item: { properties: { [type]: { allowed_lookup: allowedLookup } = {} } = {} } = {} } = {} } = {} } = this
            if (allowedLookup) {
              const { field_name: fieldName, value_name: valueName, search_path: url } = allowedLookup
              apiCall.request({
                url,
                method: 'post',
                baseURL: '', // reset
                data: {
                  query: { op: 'and', values: [{ op: 'and', values: [{ field: valueName, op: 'equals', value }] }] },
                  fields: [fieldName, valueName],
                  sort: [fieldName],
                  cursor: 0,
                  limit: 1
                }
              }).then(response => {
                const { data: { items: { 0: { [fieldName]: lookupName } = {} } = {} } = {} } = response
                if (lookupName) {
                  this.$set(this.lookupCache[type], value, `${triggerFields[type].text}: ${lookupName}`)
                }
              })
            }
          }
          return this.lookupCache[type][value]
        })
        : [this.$i18n.t('All device types')]
    },
    profilingInvalid () {
      const state = this.$store.getters[`${this.formStoreName}/$stateNS`](`${this.formNamespace}.profiling`)
      return state.$invalid && !state.$pending
    },
    usageDescription () {
      const { usage: { direction, limit, interval, type } = {} } = this.formStoreValue || {}
      if (direction && limit && interval) {
        return `${bytes.toHuman(limit, 1, true)}B ${triggerDirections[direction]}/${triggerIntervals[interval]}`
      } else if (type === 'BandwidthExpired') {
        return this.$i18n.t('Bandwidth balance has expired')
      } else if (type === 'TimeExpired') {
        return this.$i18n.t('Time balance has expired')
      } else {
        return this.$i18n.t('Any data usage')
      }
    },
    usageInvalid () {
      const state = this.$store.getters[`${this.formStoreName}/$stateNS`](`${this.formNamespace}.usage`)
      return state.$invalid && !state.$pending
    },
    eventDescription () {
      const { event: { typeValue: { type, value } = {}, fingerbank_network_behavior_policy = '' } = {} } = this.formStoreValue || {}
      let description
      if (type && value) {
        description = `${triggerFields[type].text}: ${value}`
        if (fingerbank_network_behavior_policy) {
          description += ` (${fingerbank_network_behavior_policy})`
        }
      } else {
        description = this.$i18n.t('Any event')
      }
      return description
    },
    eventInvalid () {
      const state = this.$store.getters[`${this.formStoreName}/$stateNS`](`${this.formNamespace}.event`)
      return state.$invalid && !state.$pending
    },
    view () {
      return {
        [triggerCategories.ENDPOINT]: triggerEndpointView(this.formStoreValue, this.meta),
        [triggerCategories.PROFILING]: triggerProfilingView(this.formStoreValue, this.meta),
        [triggerCategories.USAGE]: triggerUsageView(this.formStoreValue, this.meta),
        [triggerCategories.EVENT]: triggerEventView(this.formStoreValue, this.meta)
      }
    },
    mouseDown () {
      return this.$store.getters['events/mouseDown']
    }
  },
  watch: {
    mouseDown (pressed) {
      if (pressed) this.onBodyClick(this.$store.state.events.mouseEvent)
    }
  },
  methods: {
    removeCategory (category) {
      this.popover[category] = false
      this.formStoreValue[category] = {}
    },
    onBodyClick ($event) {
      const { target = {}, target: { id = '', parentNode = {} } = {} } = $event
      // parentNode still exists in DOM and at least one popover is opened
      if (parentNode && Object.values(this.popover).includes(true)) {
        // At least one popover is opened
        const isInsidePopover = Object.values(triggerCategories).find(category => {
          const refs = this.$refs[`${category}Popover`]
          return refs && refs.length > 0 && refs[0].contains(target)
        })
        if (isInsidePopover === undefined) {
          // Click is outside popover -- close all popover
          const { id: parentId } = parentNode || {}
          for (const category in this.popover) {
            // Ignore clicks on popover links
            if (![id, parentId].includes([category, this.uuid].join('_'))) {
              if (this.popover[category]) {
                // Close popover
                this.closePopover(category)
              }
            }
          }
        }
      }
    },
    closePopover (category) {
      this.popover[category] = false
    }
  }
}
</script>

<style lang="scss">
/**
 * Position the "or" badge bellow each trigger except the last one
 */
.security-event-trigger-row {
  position: relative;
  .or {
    position: absolute;
    bottom: -1em;
    left: 5em;
  }
  /**
  * Make popover larger
  */
  .popover {
    max-width: $popover-max-width * 2;
  }
}
.pf-form-field-component-container:last-child .or {
  display: none;
}

/**
 * No padding inside popover
 */
.security-event-trigger-row .popover,
.security-event-trigger-row .input-group {
  width: 100%;
}
.security-event-trigger-row .popover-body {
  padding: 0;
}
</style>
