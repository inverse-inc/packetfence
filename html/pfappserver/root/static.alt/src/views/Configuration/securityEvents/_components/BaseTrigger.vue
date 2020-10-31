<template>
  <b-container fluid>
    <b-row
      class="base-trigger base-trigger-info align-items-center flex-nowrap text-center py-2"
      :class="{
        'bg-light border-primary border-top border-right border-left': isShown
      }"
    >
      <b-badge class="or">{{ $t('OR') }}</b-badge>
      <b-col cols="2"
        :class="{
          'text-primary': isShown && isTab === 0
        }"
        @click="doTab(0)"
      >
        <span v-for="(desc, index) in endpointDescription" :key="`endpoint-${index}-${desc}`"
          :class="{ 'text-danger': endpointInvalid }"
        >
          {{ desc }} <b-badge variant="light" v-if="endpointDescription.length - index > 1">{{ $t('AND') }}</b-badge>
        </span>
      </b-col>
      <b-col>
        <b-badge>{{ $t('AND') }}</b-badge>
      </b-col>
      <b-col cols="2"
        :class="{
          'text-primary': isShown && isTab === 1
        }"
        @click="doTab(1)"
      >
        <span v-for="(desc, index) in profilingDescription" :key="`profiling-${index}-${desc}`"
          :class="{ 'text-danger': profilingInvalid }"
        >
          {{ desc }} <b-badge variant="light" v-if="profilingDescription.length - index > 1">{{ $t('AND') }}</b-badge>
        </span>
      </b-col>
      <b-col>
        <b-badge>{{ $t('AND') }}</b-badge>
      </b-col>
      <b-col cols="2"
        :class="{
          'text-primary': isShown && isTab === 2
        }"
        @click="doTab(2)"
      >
        <span :class="{ 'text-danger': usageInvalid }">{{ usageDescription }}</span>
      </b-col>
      <b-col>
        <b-badge>{{ $t('AND') }}</b-badge>
      </b-col>
      <b-col cols="2"
        :class="{
          'text-primary': isShown && isTab === 3
        }"
        @click="doTab(3)"
      >
        <span :class="{ 'text-danger': eventInvalid }">{{ eventDescription }}</span>
      </b-col>
    </b-row>

    <div v-if="isShown"
      class="base-trigger base-trigger-form row p-2 border-primary border-right border-bottom border-left"
    >

      <base-trigger-endpoint-conditions v-if="isTab === 0"
        :namespace="`${namespace}.endpoint.conditions`" />

      <base-trigger-profiling-conditions v-if="isTab === 1"
        :namespace="`${namespace}.profiling.conditions`" />

      <base-trigger-usage v-if="isTab === 2"
        :namespace="`${namespace}.usage`" />

      <base-trigger-event v-if="isTab === 3"
        :namespace="`${namespace}.event`" />

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
  triggerCategories,
  triggerCategoryTitles,
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
  } = useInputValidator(metaProps, inputValue)

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
      ? conditions.map(condition => {
        const { type, value } = condition || {}
        let { [type]: lookupType, [type]: { [value]: lookupValue } = {} } = sharedCache
        if (!lookupType)
          set(sharedCache, type, { [value]: null })
        if (!lookupValue) {
          // temporary placeholder
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
    endpointInvalid: false,
    profilingDescription,
    profilingInvalid: false,
    usageDescription,
    usageInvalid: false,
    eventDescription,
    eventInvalid: false
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
.base-trigger-info {
  position: relative;
  border-top-left-radius: $border-radius !important;
  border-top-right-radius: $border-radius !important;
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
  border-bottom-left-radius: $border-radius !important;
  border-bottom-right-radius: $border-radius !important;
  .input-group {
    width: 100%;
  }
}

.is-lastchild {
  & > .col-10 {
    & > .base-trigger-info {
      & > .or {
        display: none;
      }
    }
  }
}
</style>
