<template>
  <b-container fluid
    class="base-trigger"
    :class="{
      'border bg-light': isShown,
      'is-shown': isShown,
      'is-invalid': inputState === false,
    }"
  >
    <b-row
      class="base-trigger base-trigger-info align-items-center flex-nowrap text-center py-2"
    >
      <b-badge class="or" v-if="!isShown">{{ $t('OR') }}</b-badge>
      <b-col cols="2"
        class="base-trigger-description" :class="{
          'is-tab': isTab === 0
        }"
        @click="doTab(0)"
      >
        <span v-for="(desc, index) in endpointDescription" :key="`endpoint-${index}-${desc}`">
          {{ desc }} <b-badge variant="light" v-if="endpointDescription.length - index > 1">{{ $t('AND') }}</b-badge>
        </span>
      </b-col>
      <b-col>
        <b-badge>{{ $t('AND') }}</b-badge>
      </b-col>
      <b-col cols="2"
        class="base-trigger-description" :class="{
          'is-tab': isTab === 1
        }"
        @click="doTab(1)"
      >
        <span v-for="(desc, index) in profilingDescription" :key="`profiling-${index}-${desc}`">
          {{ desc }} <b-badge variant="light" v-if="profilingDescription.length - index > 1">{{ $t('AND') }}</b-badge>
        </span>
      </b-col>
      <b-col>
        <b-badge>{{ $t('AND') }}</b-badge>
      </b-col>
      <b-col cols="2"
        class="base-trigger-description" :class="{
          'is-tab': isTab === 2
        }"
        @click="doTab(2)"
      >
        {{ usageDescription }}
      </b-col>
      <b-col>
        <b-badge>{{ $t('AND') }}</b-badge>
      </b-col>
      <b-col cols="2"
        class="base-trigger-description" :class="{
          'is-tab': isTab === 3
        }"
        @click="doTab(3)"
      >
        {{ eventDescription }}
      </b-col>
    </b-row>

    <div v-if="isShown"
      class="base-trigger base-trigger-form row mx-1 mb-3"
    >

      <b-card v-show="isTab === 0"
        no-body class="w-100"
      >
        <b-card-header>
          <h5 class="mb-0 d-inline">{{ $t('Endpoint') }}</h5>
          <b-button-close @click="toggleShown" class="float-right" scale="0.5" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
        </b-card-header>
        <base-trigger-endpoint-conditions :namespace="`${namespace}.endpoint.conditions`"
          class="card-body p-3"
        />
      </b-card>

      <b-card v-show="isTab === 1"
        no-body class="w-100"
      >
        <b-card-header>
          <h5 class="mb-0 d-inline">{{ $t('Device Profiling') }}</h5>
          <b-button-close @click="toggleShown" class="float-right" scale="0.5" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
        </b-card-header>
        <base-trigger-profiling-conditions :namespace="`${namespace}.profiling.conditions`"
          class="card-body p-3"
        />
      </b-card>

      <b-card v-show="isTab === 2"
        no-body class="w-100"
      >
        <b-card-header>
          <h5 class="mb-0 d-inline">{{ $t('Data Usage') }}</h5>
          <b-button-close @click="toggleShown" class="float-right" scale="0.5" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
        </b-card-header>
        <base-trigger-usage :namespace="`${namespace}.usage`"
          class="card-body p-3"
        />
      </b-card>

      <b-card v-show="isTab === 3"
        no-body class="w-100"
      >
        <b-card-header>
          <h5 class="mb-0 d-inline">{{ $t('Event') }}</h5>
          <b-button-close @click="toggleShown" class="float-right" scale="0.5" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"/></b-button-close>
        </b-card-header>
        <base-trigger-event :namespace="`${namespace}.event.typeValue`"
          class="card-body p-3"
        />
      </b-card>

    </div>
  </b-container>
</template>
<script>
import BaseTriggerEndpointConditions from './BaseTriggerEndpointConditions'
import BaseTriggerEvent from './BaseTriggerEvent'
import BaseTriggerProfilingConditions from './BaseTriggerProfilingConditions'
import BaseTriggerUsage from './BaseTriggerUsage'

const components = {
  BaseTriggerEndpointConditions,
  BaseTriggerEvent,
  BaseTriggerProfilingConditions,
  BaseTriggerUsage
}

import { computed, inject, reactive, ref, set, toRefs } from '@vue/composition-api'
import uuidv4 from 'uuid/v4'
import { useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps, useNamespaceMetaAllowedLookupFn } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import apiCall from '@/utils/api'
import bytes from '@/utils/bytes'
import i18n from '@/utils/locale'

const props = {
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,

  value: {
    type: Object
  }
}

import {
  triggerFields,
  triggerDirections,
  triggerIntervals
} from '../config'

const setup = (props, context) => {

  // inject shared API lookup cache from parent form
  const sharedCache = inject('sharedCache', reactive({}))

  // inject shared uuid, singleton view
  const showUuid = inject('showUuid', ref(null))

  // unique id for multiple instances
  const uuid = ref(uuidv4())

  const isShown = computed(() => showUuid.value === uuid.value)
  const toggleShown = () => {
    showUuid.value = (showUuid.value === uuid.value) ? null : uuid.value
  }

  const isTab = ref(0)
  const doTab = (tab) => {
    if (!isShown.value || isTab.value === tab)
      toggleShown()
    isTab.value = tab
  }

  const {
    namespace
  } = toRefs(props)

  const metaProps = useInputMeta(props, context)

  const {
    value: inputValue
  } = useInputValue(metaProps, context)

  const {
    state
  } = useInputValidator(metaProps, inputValue, true)

  const endpointDescription = computed(() => {
    const { endpoint: { conditions = [] } = {} } = inputValue.value || {}
    const filteredConditions = conditions.filter(condition => {
      const { type, value } = condition || {}
      return type && value
    })
    return filteredConditions.length > 0
      ? filteredConditions.map(condition => {
        const { type, value } = condition || {}
        return `${triggerFields[type].text}: ${value}`
      })
      : [i18n.t('No condition')]
  })

  const profilingDescription = computed(() => {
    const { profiling: { conditions = [] } = {} } = inputValue.value || {}
    const filteredConditions = conditions.filter(condition => {
      const { type, value } = condition || {}
      return type && value
    })
    return filteredConditions.length > 0
      ? filteredConditions.map(condition => {
        const { type, value } = condition || {}
        let { [type]: lookupType, [type]: { [value]: lookupValue } = {} } = sharedCache
        // declare temporary placeholder
        if (!lookupType)
          set(sharedCache, type, { [value]: null })
        if (!lookupValue) {
          if (type in triggerFields)
            set(sharedCache[type], value, `${triggerFields[type].text}: ${value}`)
          // perform lookup
          useNamespaceMetaAllowedLookupFn(`${namespace.value}.${type}`, meta => {
            const { field_name: fieldName, value_name: valueName, search_path: url } = meta
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
              if (lookupName)
                set(sharedCache[type], value, `${triggerFields[type].text}: ${lookupName}`)
            })
          })
        }
        return sharedCache[type][value]
      })
      : [i18n.t('All device types')]
  })

  const usageDescription  = computed(() => {
    const { usage: { direction, limit, interval, type } = {} } = inputValue.value || {}
    if (direction && limit && interval)
      return `${bytes.toHuman(limit, 1, true)}B ${triggerDirections[direction]}/${triggerIntervals[interval]}`
    else if (type === 'BandwidthExpired')
      return i18n.t('Bandwidth balance has expired')
    else if (type === 'TimeExpired')
      return i18n.t('Time balance has expired')
    else
      return i18n.t('Any data usage')
  })

  const eventDescription = computed(() => {
    var { event: { typeValue: { type, value } = {}, fingerbank_network_behavior_policy = '' } = {} } = inputValue.value || {}
    let description
    if (type && value) {
      description = `${triggerFields[type].text}: ${value}`
      if (fingerbank_network_behavior_policy)
        description += ` (${fingerbank_network_behavior_policy})`
    }
    else
      description = i18n.t('Any event')
    return description
  })

  return {
    inputState: state,
    inputValue,

    uuid,
    isShown,
    toggleShown,

    isTab,
    doTab,

    endpointDescription,
    profilingDescription,
    usageDescription,
    eventDescription
  }
}

// @vue/component
export default {
  name: 'base-trigger',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.base-trigger {
  border-radius: $border-radius !important;
  border-color: var(--secondary);
  .base-trigger-info {
    position: relative;
    /**
    * Position the "or" badge below each trigger except the last one
    */
    .or {
      position: absolute;
      bottom: -.75em;
      left: -1.5em;
    }
    &:hover {
      cursor: pointer;
    }
  }
  .base-trigger-form {
    .input-group {
      width: 100%;
    }
  }
  &.is-shown:not(.is-invalid) {
    .base-trigger-description.is-tab {
      color: var(--primary);
    }
  }
  &.is-invalid {
    .base-trigger-description {
      color: var(--danger);
    }
  }
}
.is-lastchild {
  & > .col-10 {
    & > .base-trigger {
      & > .base-trigger-info {
        & > .or {
          display: none;
        }
      }
    }
  }
}
</style>
