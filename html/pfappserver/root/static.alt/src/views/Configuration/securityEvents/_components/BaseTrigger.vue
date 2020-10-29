<template>
  <b-form-row :id="`security-event-trigger-${uuid}`"
    class="base-trigger align-items-center flex-nowrap text-center py-1"
    :class="{
      'text-primary': showPopover
    }"
    @click="togglePopover"
  >
    <b-badge class="or">{{ $t('OR') }}</b-badge>
    <b-col cols="2">
      <span v-for="(desc, index) in endpointDescription" :key="`endpoint-${desc}`"
        :class="{ 'text-danger': endpointInvalid }"
      >
        {{ desc }} <b-badge variant="light" v-if="endpointDescription.length - index > 1">{{ $t('AND') }}</b-badge>
      </span>
  </b-col>
    <b-col>
      <b-badge>{{ $t('AND') }}</b-badge>
    </b-col>
    <b-col cols="2">
      <span v-for="(desc, index) in profilingDescription" :key="`profiling-${desc}`"
        :class="{ 'text-danger': profilingInvalid }"
      >
        {{ desc }} <b-badge variant="light" v-if="profilingDescription.length - index > 1">{{ $t('AND') }}</b-badge>
      </span>
    </b-col>
    <b-col>
      <b-badge>{{ $t('AND') }}</b-badge>
    </b-col>
    <b-col cols="2">
      <span :class="{ 'text-danger': usageInvalid }">{{ usageDescription }}</span>
    </b-col>
    <b-col>
      <b-badge>{{ $t('AND') }}</b-badge>
    </b-col>
    <b-col cols="2">
      <span :class="{ 'text-danger': eventInvalid }">{{ eventDescription }}</span>
    </b-col>

    <b-popover
      triggers=""
      placement="top"
      :show.sync="showPopover"
      :target="`security-event-trigger-${uuid}`"
      container="body"
    >

{{ uuid }}

    </b-popover>

  </b-form-row>
</template>
<script>
import { computed, customRef, inject, reactive, ref, set, toRefs } from '@vue/composition-api'
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

  const {
    namespace
  } = toRefs(props)

  // inject shared API lookup cache from parent form
  const sharedCache = inject('sharedCache', reactive({}))

  // inject shared popover uuid
  const popoverUuid = inject('popoverUuid', ref(null))

  // unique id for multiple popover instances
  const uuid = ref(uuidv4())

  const metaProps = useInputMeta(props, context)

  const {
    value: inputValue
  } = useInputValue(metaProps, context)

  const {
    state
  } = useInputValidator(metaProps, inputValue)

  const endpointDescription = computed(() => {
    const { endpoint: { conditions = [] } = {} } = inputValue.value || {}
    return conditions.filter(condition => {
      const { type, value } = condition || {}
      return type && value
    }).length > 0
      ? conditions.map(condition => {
        const { type, value } = condition || {}
        return `${triggerFields[type].text}: ${value}`
      })
      : [i18n.t('No condition')]
  })

  const profilingDescription = computed(() => {
    const { profiling: { conditions = [] } = {} } = inputValue.value || {}
    return conditions.filter(condition => {
      const { type, value } = condition || {}
      return type && value
    }).length > 0
      ? conditions.map(condition => {
        const { type, value } = condition || {}
        let { [type]: lookupType, [type]: { [value]: lookupValue } = {} } = sharedCache
        if (!lookupType)
          set(sharedCache, type, { [value]: null })
        if (!lookupValue) {
          // temporary placeholder
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

  const showPopover = customRef((track, trigger) => ({
    get() {
      track()
      return popoverUuid.value === uuid.value
    },
    set(newValue) { // <b-popover :show.sync /> mutates value
      if (newValue)
        popoverUuid.value = uuid.value
      trigger()
    }
  }))

  const togglePopover = () => {
    popoverUuid.value = (!showPopover.value) ? uuid.value : null
  }

  return {
    inputState: state,
    inputValue,

    uuid,
    showPopover,
    togglePopover,

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
  props,
  setup
}
</script>
<style lang="scss">
/**
 * Position the "or" badge below each trigger except the last one
 */
.base-trigger {
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
  &:hover {
    cursor: pointer;
    color: var(--primary);
  }
}
.base-form-group-array-items:last-child .or {
  display: none;
}

/**
 * No padding inside popover
 */
.base-trigger .popover,
.base-trigger .input-group {
  width: 100%;
}
.base-trigger .popover-body {
  padding: 0;
}
</style>
