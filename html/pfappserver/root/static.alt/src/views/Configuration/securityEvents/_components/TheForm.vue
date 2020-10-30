<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-enabled namespace="enabled"
      :column-label="$i18n.t('Enable security event')"
    />

    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Identifier')"
    />

    <form-group-description namespace="desc"
      :column-label="$i18n.t('Description')"
    />

    <form-group-priority namespace="priority"
      :column-label="$i18n.t('Priority')"
      :text="$i18n.t('When multiple violations are opened for an endpoint, the one with the lowest priority takes precedence.')"
    />

    <form-group-whitelisted-roles namespace="whitelisted_roles"
      :column-label="$i18n.t('Ignored Roles')"
      :text="$i18n.t(`Which roles shouldn't be impacted by this security event.`)"
    />

    <form-group-triggers namespace="triggers"
      :column-label="$i18n.t('Event Triggers')"
    />

    <form-group-actions
      :column-label="$i18n.t('Event Actions')"
    />

    <form-group-window-dynamic namespace="window_dynamic"
      :column-label="$i18n.t('Dynamic Window')"
      :text="$i18n.t('Only works for accounting security events. The security event will be opened according to the time you set in the accounting security event (ie. You have an accounting security event for 10GB/month. If you bust the bandwidth after 3 days, the security event will open and the release date will be set for the last day of the current month).')"
    />

    <form-group-grace :namespaces="['grace.interval', 'grace.unit']"
      :column-label="$i18n.t('Grace')"
      :text="$i18n.t('Amount of time before the security event can reoccur. This is useful to allow hosts time (in the example 2 minutes) to download tools to fix their issue, or shutoff their peer-to-peer application.')"
    />

    <form-group-window :namespaces="['window.interval', 'window.unit']"
      :column-label="$i18n.t('Window')"
      :text="$i18n.t('Amount of time before a security event will be closed automatically. Instead of allowing people to reactivate the network, you may want to open a security event for a defined amount of time instead.')"
    />

    <form-group-delay-by :namespaces="['delay_by.interval', 'delay_by.unit']"
      :column-label="$i18n.t('Delay By')"
      :text="$i18n.t('Delay before triggering the security event.')"
    />
<pre>{{ {form} }}</pre>
  </base-form>
</template>
<script>
import { computed, provide, reactive, ref, toRefs, watch } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupActions,
  FormGroupDelayBy,
  FormGroupDescription,
  FormGroupEnabled,
  FormGroupGrace,
  FormGroupIdentifier,
  FormGroupPriority,
  FormGroupTriggers,
  FormGroupWhitelistedRoles,
  FormGroupWindow,
  FormGroupWindowDynamic
} from './'

const components = {
  BaseForm,

  FormGroupActions,
  FormGroupDelayBy,
  FormGroupDescription,
  FormGroupEnabled,
  FormGroupGrace,
  FormGroupIdentifier,
  FormGroupPriority,
  FormGroupTriggers,
  FormGroupWhitelistedRoles,
  FormGroupWindow,
  FormGroupWindowDynamic
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  },
  id: {
    type: String
  }
}

export const setup = (props) => {

  const {
    id
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  // provide a shared cache to all child components
  const sharedCache = reactive({})
  provide('sharedCache', sharedCache)

  // provide a shared uuid to all child components
  const showUuid = ref(null)
  provide('showUuid', showUuid)

  // clear shown uuid when local `id` changes
  watch(id, () => {
    showUuid.value = null
  })

  return {
    schema
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
