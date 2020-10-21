<template>
  <b-container class="px-0" fluid>

    <component v-if="formType"
      :is="formType" v-bind="$props"
    />

    <b-container class="my-5 py-5" v-else>
      <b-row class="justify-content-md-center text-secondary">
        <b-col cols="12" md="auto">
          <b-media v-if="isLoading">
            <template v-slot:aside>
              <icon name="circle-notch" scale="2" spin></icon>
            </template>
            <h4>{{ $t('Building Form') }}</h4>
            <p class="font-weight-light">{{ $t('Hold on a moment while we render it...') }}</p>
          </b-media>
          <b-media v-else>
            <template v-slot:aside><icon name="question-circle" scale="2"></icon></template>
            <h4>{{ $t('Unhandled source type') }}</h4>
          </b-media>
        </b-col>
      </b-row>
    </b-container>

  </b-container>
</template>
<script>
import { computed, toRefs, unref } from '@vue/composition-api'
import { useFormProps } from '../_composables/useForm'
import FormTypeActiveDirectory from './FormTypeActiveDirectory'
import FormTypeAdminProxy from './FormTypeAdminProxy'
import FormTypeAuthorization from './FormTypeAuthorization'
import FormTypeAuthorizeNet from './FormTypeAuthorizeNet'
import FormTypeBlackhole from './FormTypeBlackhole'
import FormTypeClickatell from './FormTypeClickatell'
import FormTypeEapTls from './FormTypeEapTls'
import FormTypeEduroam from './FormTypeEduroam'
import FormTypeEmail from './FormTypeEmail'
import FormTypeFacebook from './FormTypeFacebook'
import FormTypeGithub from './FormTypeGithub'
import FormTypeGoogle from './FormTypeGoogle'
import FormTypeHtpasswd from './FormTypeHtpasswd'
import FormTypeHttp from './FormTypeHttp'
import FormTypeInstagram from './FormTypeInstagram'
import FormTypeKerberos from './FormTypeKerberos'
import FormTypeKickbox from './FormTypeKickbox'
import FormTypeLinkedIn from './FormTypeLinkedIn'
import FormTypeMirapay from './FormTypeMirapay'
import FormTypeNull from './FormTypeNull'
import FormTypeOpenId from './FormTypeOpenId'
import FormTypePaypal from './FormTypePaypal'
import FormTypePinterest from './FormTypePinterest'
import FormTypePotd from './FormTypePotd'
import FormTypeRadius from './FormTypeRadius'
import FormTypeSaml from './FormTypeSaml'
import FormTypeSms from './FormTypeSms'
import FormTypeSponsorEmail from './FormTypeSponsorEmail'
import FormTypeStripe from './FormTypeStripe'
import FormTypeTwilio from './FormTypeTwilio'
import FormTypeTwitter from './FormTypeTwitter'
import FormTypeWindowsLive from './FormTypeWindowsLive'

const components = {
  FormTypeActiveDirectory,
  FormTypeAdminProxy,
  FormTypeAuthorization,
  FormTypeAuthorizeNet,
  FormTypeBlackhole,
  FormTypeClickatell,
  FormTypeEapTls,
  FormTypeEduroam,
  FormTypeEmail,
  FormTypeFacebook,
  FormTypeGithub,
  FormTypeGoogle,
  FormTypeHtpasswd,
  FormTypeHttp,
  FormTypeInstagram,
  FormTypeKerberos,
  FormTypeKickbox,
  FormTypeLinkedIn,
  FormTypeMirapay,
  FormTypeNull,
  FormTypeOpenId,
  FormTypePaypal,
  FormTypePinterest,
  FormTypePotd,
  FormTypeRadius,
  FormTypeSaml,
  FormTypeSms,
  FormTypeSponsorEmail,
  FormTypeStripe,
  FormTypeTwilio,
  FormTypeTwitter,
  FormTypeWindowsLive,
}

export const props = useFormProps

export const setup = (props) => {

  const {
    form
  } = toRefs(props)

  const formType = computed(() => {
    const { type } = unref(form)
    switch(unref(type)) {
      case 'AD':            return FormTypeActiveDirectory // break
      case 'AdminProxy':    return FormTypeAdminProxy //break
      case 'Authorization': return FormTypeAuthorization //break
      case 'AuthorizeNet':  return FormTypeAuthorizeNet //break
      case 'Blackhole':     return FormTypeBlackhole //break
      case 'Clickatell':    return FormTypeClickatell //break
      case 'EAPTLS':        return FormTypeEapTls //break
      case 'Eduroam':       return FormTypeEduroam // break
      case 'Email':         return FormTypeEmail //break
      case 'Facebook':      return FormTypeFacebook //break
      case 'Github':        return FormTypeGithub //break
      case 'Google':        return FormTypeGoogle //break
      case 'Htpasswd':      return FormTypeHtpasswd //break
      case 'HTTP':          return FormTypeHttp //break
      case 'Instagram':     return FormTypeInstagram //break
      case 'Kerberos':      return FormTypeKerberos //break
      case 'Kickbox':       return FormTypeKickbox //break
      case 'LDAP':          return FormTypeActiveDirectory //break
      case 'LinkedIn':      return FormTypeLinkedIn //break
      case 'Mirapay':       return FormTypeMirapay //break
      case 'Null':          return FormTypeNull //break
      case 'OpenID':        return FormTypeOpenId //break
      case 'Paypal':        return FormTypePaypal //break
      case 'Pinterest':     return FormTypePinterest //break
      case 'Potd':          return FormTypePotd //break
      case 'RADIUS':        return FormTypeRadius //break
      case 'SAML':          return FormTypeSaml //break
      case 'SMS':           return FormTypeSms //break
      case 'SponsorEmail':  return FormTypeSponsorEmail //break
      case 'Stripe':        return FormTypeStripe //break
      case 'Twilio':        return FormTypeTwilio //break
      case 'Twitter':       return FormTypeTwitter //break
      case 'WindowsLive':   return FormTypeWindowsLive //break
      default:              return undefined
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
