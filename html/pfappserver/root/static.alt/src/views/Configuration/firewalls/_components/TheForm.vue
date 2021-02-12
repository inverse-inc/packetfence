<template>
  <b-container class="px-0" fluid>
    <component v-if="formType"
      :is="formType" v-bind="$props"
    />

    <base-container-loading v-else-if="isLoading"
      :title="$i18n.t('Building Form')"
      :text="$i18n.t('Hold on a moment while we render it...')"
      spin
    />

    <base-container-loading v-else
      :title="$i18n.t('Unhandled firewall type')"
      icon="question-circle"
    />
  </b-container>
</template>
<script>
import { BaseContainerLoading } from '@/components/new/'
import FormTypeBarracudaNg from './FormTypeBarracudaNg'
import FormTypeCheckpoint from './FormTypeCheckpoint'
import FormTypeCiscoIsePic from './FormTypeCiscoIsePic'
import FormTypeFamilyZone from './FormTypeFamilyZone'
import FormTypeFortiGate from './FormTypeFortiGate'
import FormTypeIboss from './FormTypeIboss'
import FormTypeJsonRpc from './FormTypeJsonRpc'
import FormTypeJuniperSrx from './FormTypeJuniperSrx'
import FormTypeLightSpeedRocket from './FormTypeLightSpeedRocket'
import FormTypePaloAlto from './FormTypePaloAlto'
import FormTypeSmoothWall from './FormTypeSmoothWall'
import FormTypeWatchGuard from './FormTypeWatchGuard'

const components = {
  BaseContainerLoading,

  FormTypeBarracudaNg,
  FormTypeCheckpoint,
  FormTypeCiscoIsePic,
  FormTypeFamilyZone,
  FormTypeFortiGate,
  FormTypeIboss,
  FormTypeJsonRpc,
  FormTypeJuniperSrx,
  FormTypeLightSpeedRocket,
  FormTypePaloAlto,
  FormTypeSmoothWall,
  FormTypeWatchGuard
}

import { computed, toRefs, unref } from '@vue/composition-api'
import { useItemProps } from '../_composables/useCollection'
import { useForm, useFormProps } from '../_composables/useForm'

const props = {
  ...useItemProps,
  ...useFormProps
}

export const setup = (props) => {

  const {
    form
  } = toRefs(props)

  const formType = computed(() => {
    const { type } = unref(form)
    switch(type) {
      case 'BarracudaNG':
        return FormTypeBarracudaNg // break
      case 'Checkpoint':
        return FormTypeCheckpoint // break
      case 'CiscoIsePic':
        return FormTypeCiscoIsePic // break
      case 'FamilyZone':
        return FormTypeFamilyZone // break
      case 'FortiGate':
        return FormTypeFortiGate // break
      case 'Iboss':
        return FormTypeIboss // break
      case 'JSONRPC':
        return FormTypeJsonRpc // break
      case 'JuniperSRX':
        return FormTypeJuniperSrx // break
      case 'LightSpeedRocket':
        return FormTypeLightSpeedRocket // break
      case 'PaloAlto':
        return FormTypePaloAlto // break
      case 'SmoothWall':
        return FormTypeSmoothWall // break
      case 'WatchGuard':
        return FormTypeWatchGuard // break
      default:
        return undefined
    }
  })

  return {
    ...useForm(props),

    formType
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
