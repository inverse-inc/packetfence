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
      :title="$i18n.t('Unhandled module type')"
      icon="question-circle"
    />
  </b-container>
</template>
<script>
import { computed, toRefs, unref } from '@vue/composition-api'
import { useFormProps as props } from '../_composables/useForm'
import { BaseContainerLoading } from '@/components/new/'
import FormTypeChoice from './FormTypeChoice'
import FormTypeChained from './FormTypeChained'
import FormTypeAuthenticationBilling from './FormTypeAuthenticationBilling'
import FormTypeAuthenticationBlackhole from './FormTypeAuthenticationBlackhole'
import FormTypeAuthenticationChoice from './FormTypeAuthenticationChoice'
import FormTypeAuthenticationEmail from './FormTypeAuthenticationEmail'
import FormTypeAuthenticationLogin from './FormTypeAuthenticationLogin'
import FormTypeAuthenticationNull from './FormTypeAuthenticationNull'
import FormTypeAuthenticationOauth from './FormTypeAuthenticationOauth'
import FormTypeAuthenticationPassword from './FormTypeAuthenticationPassword'
import FormTypeAuthenticationSaml from './FormTypeAuthenticationSaml'
import FormTypeAuthenticationSms from './FormTypeAuthenticationSms'
import FormTypeAuthenticationSponsor from './FormTypeAuthenticationSponsor'
import FormTypeFixedRole from './FormTypeFixedRole'
import FormTypeMessage from './FormTypeMessage'
import FormTypeProvisioning from './FormTypeProvisioning'
import FormTypeRoot from './FormTypeRoot'
import FormTypeSelectRole from './FormTypeSelectRole'
import FormTypeShowLocalAccount from './FormTypeShowLocalAccount'
import FormTypeSslInspection from './FormTypeSslInspection'
import FormTypeSurvey from './FormTypeSurvey'
import FormTypeUrl from './FormTypeUrl'

const components = {
  BaseContainerLoading,

  FormTypeChoice,
  FormTypeChained,
  FormTypeAuthenticationBilling,
  FormTypeAuthenticationBlackhole,
  FormTypeAuthenticationChoice,
  FormTypeAuthenticationEmail,
  FormTypeAuthenticationLogin,
  FormTypeAuthenticationNull,
  FormTypeAuthenticationOauth,
  FormTypeAuthenticationPassword,
  FormTypeAuthenticationSaml,
  FormTypeAuthenticationSms,
  FormTypeAuthenticationSponsor,
  FormTypeFixedRole,
  FormTypeMessage,
  FormTypeProvisioning,
  FormTypeRoot,
  FormTypeSelectRole,
  FormTypeShowLocalAccount,
  FormTypeSslInspection,
  FormTypeSurvey,
  FormTypeUrl
}

export const setup = (props) => {

  const {
    form
  } = toRefs(props)

  const formType = computed(() => {
    const { type } = unref(form)
    switch(unref(type)) {
      case 'Chained':
        return FormTypeChained // break

      case 'Choice':
        return FormTypeChoice // break

      case 'Authentication::Billing':
        return FormTypeAuthenticationBilling // break

      case 'Authentication::Blackhole':
        return FormTypeAuthenticationBlackhole // break

      case 'Authentication::Choice':
        return FormTypeAuthenticationChoice // break

      case 'Authentication::Email':
        return FormTypeAuthenticationEmail // break

      case 'Authentication::Login':
        return FormTypeAuthenticationLogin // break

      case 'Authentication::Null':
        return FormTypeAuthenticationNull // break

      case 'Authentication::OAuth::Facebook':
      case 'Authentication::OAuth::Github':
      case 'Authentication::OAuth::Google':
      case 'Authentication::OAuth::LinkedIn':
      case 'Authentication::OAuth::OpenID':
      case 'Authentication::OAuth::WindowsLive':
        return FormTypeAuthenticationOauth // break

      case 'Authentication::Password':
        return FormTypeAuthenticationPassword // break

      case 'Authentication::SAML':
        return FormTypeAuthenticationSaml // break

      case 'Authentication::SMS':
        return FormTypeAuthenticationSms // break

      case 'Authentication::Sponsor':
        return FormTypeAuthenticationSponsor // break

      case 'FixedRole':
        return FormTypeFixedRole // break

      case 'Message':
        return FormTypeMessage // break

      case 'Provisioning':
        return FormTypeProvisioning // break

      case 'Root':
        return FormTypeRoot // break

      case 'SelectRole':
        return FormTypeSelectRole // break

      case 'ShowLocalAccount':
        return FormTypeShowLocalAccount // break

      case 'SSL_Inspection':
        return FormTypeSslInspection // break

      case 'Survey':
        return FormTypeSurvey // break

      case 'URL':
        return FormTypeUrl // break

      default:
        return undefined
    }
  })

  return {
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
