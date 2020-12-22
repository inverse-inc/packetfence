<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-bounce-duration :namespaces="['bounce_duration.interval', 'bounce_duration.unit']"
      :column-label="$i18n.t('Bounce duration')"
      :text="$i18n.t('Delay to wait between the shut / no-shut on a port. Some OS need a higher value than others. Default should be reasonable for almost every OS but is too long for the usual proprietary OS.')"
    />

    <form-group-trap-limit namespace="trap_limit"
      :column-label="$i18n.t('Trap limiting')"
      :text="$i18n.t('Controls whether or not the trap limit feature is enabled. Trap limiting is a way to limit the damage done by malicious users or misbehaving switch that sends too many traps to PacketFence causing it to be overloaded. Trap limiting is controlled by the trap limit threshold and trap limit action parameters. Default is enabled.')"
    />

    <form-group-trap-limit-threshold namespace="trap_limit_threshold"
      :column-label="$i18n.t('Trap limiting threshold')"
      :text="$i18n.t('Maximum number of SNMP traps that a switchport can send to PacketFence within a minute without being flagged as DoS. Defaults to 100.')"
    />

    <form-group-trap-limit-action namespace="trap_limit_action"
      :column-label="$i18n.t('Trap limit action')"
      :text="$i18n.t(`Action that PacketFence will take if the snmp_traps.trap_limit_threshold is reached. Defaults to none. Email will send an email every hour if the limit's still reached. shut will shut the port on the switch and will also send an email even if email is not specified.`)"
    />
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupBounceDuration,
  FormGroupTrapLimit,
  FormGroupTrapLimitThreshold,
  FormGroupTrapLimitAction
} from './'

const components = {
  BaseForm,

  FormGroupBounceDuration,
  FormGroupTrapLimit,
  FormGroupTrapLimitThreshold,
  FormGroupTrapLimitAction
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {

  const schema = computed(() => schemaFn(props))

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

