<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
    :isReadonly="id === 'default' && !isClone"
  >
    <form-group-identifier namespace="id"
                           :column-label="$i18n.t('Identifier')"
                           :disabled="!isNew && !isClone"
    />

    <form-group-tls namespace="tls"
                    :column-label="$i18n.t('TLS Profile')"
                    :text="$i18n.t('The TLS Profile for EAP-TEAP')"
    />

    <form-group-authority-identity namespace="authority_identity"
                                   :column-label="$i18n.t('Authority Identity')"
                                   :text="$i18n.t('Authority ID of the server, If you are running a cluster of RADIUS server, you should make the value chose here the same on all your RADIUS servers. This value should be unique to your installation.')"
    />

    <form-group-identity-types namespace="identity_types"
                               :column-label="$i18n.t('Identity Types')"
                               :text="$i18n.t('This sets &session-state:FreeRADIUS-EAP-TEAP-TLV-Identity-Type with the relevant values. The TEAP module then picks those values, in order, to authenticate the chosen identity.')"

    />

    <form-group-default-eap-type namespace="default_eap_type"
                                 :column-label="$i18n.t('Default EAP Type')"
                                 :text="$i18n.t('The default EAP type used inside the TEAP tunnel when no EAP-Type is set by another module.')"
    />
  </base-form>
</template>
<script>
import {computed} from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupTls,
  FormGroupAuthorityIdentity,
  FormGroupIdentityTypes,
  FormGroupDefaultEapType
} from './'

const components = {
  BaseForm,

  FormGroupIdentifier,
  FormGroupTls,
  FormGroupAuthorityIdentity,
  FormGroupIdentityTypes,
  FormGroupDefaultEapType
}

export const props = {
  id: {
    type: String
  },
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
