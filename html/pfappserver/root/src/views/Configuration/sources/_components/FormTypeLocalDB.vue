<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Name')"
      :disabled="!isNew && !isClone"
    />

    <form-group-description namespace="description"
      :column-label="$i18n.t('Description')"
    />

    <form-group-realms namespace="realms"
      :column-label="$i18n.t('Associated Realms')"
      :text="$i18n.t('Realms that will be associated with this source.')"
    />

    <form-group-fallback-to-static-user-attributes namespace="fallback_to_static_user_attributes"
      :column-label="$i18n.t('Fallback to Static User Attributes')"
      :text="$i18n.t('Assign the static attributes stored on the user itself when no rule of this source matches.')"
      enabled-value="1"
      disabled-value="0"
    />

    <base-form-group>
      <b-alert show variant="warning" class="w-100 mb-0">
        <p class="mb-2">{{ $i18n.t('When disabled, only the actions configured in this source apply. Administrator lockout possible.') }}</p>
        <p class="mb-0">{{ $i18n.t('The static user attributes are the actions stored on the user itself, under Users -> (user) -> Actions.') }}</p>
      </b-alert>
    </base-form-group>

    <form-group-authentication-rules namespace="authentication_rules"
      :column-label="$i18n.t('Authentication Rules')"
    />

    <base-form-group>
      <b-alert show variant="warning" class="w-100 mb-0">
        {{ $i18n.t('A catchall administration rule changes the access level of every user of the local database and can lock administrators out. Always give administration rules a condition.') }}
      </b-alert>
    </base-form-group>

    <form-group-administration-rules namespace="administration_rules"
      :column-label="$i18n.t('Administration Rules')"
    />
  </base-form>
</template>
<script>
import {
  BaseForm,
  BaseFormGroup
} from '@/components/new/'
import {
  FormGroupAdministrationRules,
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupFallbackToStaticUserAttributes,
  FormGroupIdentifier,
  FormGroupRealms,
} from './'

const components = {
  BaseForm,
  BaseFormGroup,

  FormGroupAdministrationRules,
  FormGroupAuthenticationRules,
  FormGroupDescription,
  FormGroupFallbackToStaticUserAttributes,
  FormGroupIdentifier,
  FormGroupRealms,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-local-db',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
