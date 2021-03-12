+<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'General'"/>
    </b-card-header>
    <b-form>
      <base-form
        :form="form"
        :meta="meta"
        :schema="schema"
        :isLoading="isLoading"
        :readonly="disabled"
      >
        <form-group-domain namespace="domain"
          :column-label="$i18n.t('Domain')"
          :text="$i18n.t('Domain name of PacketFence system.')"
        />

        <form-group-hostname namespace="hostname"
          :column-label="$i18n.t('Hostname')"
          :text="$i18n.t('Hostname of PacketFence system. This is concatenated with the domain in Apache rewriting rules and therefore must be resolvable by clients. Changing this requires to restart haproxy-portal.')"
        />

        <form-group-timezone namespace="timezone"
          :column-label="$i18n.t('Timezone')"
          :text="$i18n.t(`System's timezone in string format. List generated from Perl library DateTime::TimeZone. When left empty, it will use the timezone of the server.`)"
        />

        <base-form-group
          :column-label="$i18n.t('Track Configuration')"
          :text="$i18n.t('This service will track all changes to the configuration. Notice that the content of all files (except domain.conf) under /usr/local/pf/conf will be tracked, including passwords.')"
        >
          <base-button-service service="tracking-config" start stop
            :disabled="isLoading" class="px-0 col-md-7 col-lg-5 col-xl-4" acl="" />
        </base-form-group>
      </base-form>
    </b-form>
  </b-card>
</template>
<script>
import {
  BaseForm,
  BaseFormGroup,
  BaseButtonService
} from '@/components/new/'
import {
  FormGroupDomain,
  FormGroupHostname,
  FormGroupTimezone
} from '@/views/Configuration/general/_components/'

const components = {
  BaseForm,
  BaseFormGroup,
  BaseButtonService,

  FormGroupDomain,
  FormGroupHostname,
  FormGroupTimezone
}

const props = {
  disabled: {
    type: Boolean
  }
}

import { computed, inject, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import schemaFn from '@/views/Configuration/general/schema'

export const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const state = inject('state') // Configurator
  const form = ref({})
  $store.dispatch('$_bases/getGeneral').then(_form => form.value = _form)

  const meta = ref({})
  $store.dispatch('$_bases/optionsGeneral').then(({ meta: _meta }) => meta.value = _meta)

  const schema = computed(() => schemaFn(props))

  const isLoading = computed(() => $store.getters['$_bases/isLoading'])

  const onSave = () => {
    const { timezone } = form.value
    return $store.dispatch('$_bases/getGeneral')
      .then(({ timezone: initialTimezone }) => {
        let restartMariaDB = (initialTimezone !== timezone)
        return $store.dispatch('$_bases/updateGeneral', Object.assign({ quiet: true }, form.value))
          .then(() => {
            state.value.general = form.value
            if (restartMariaDB)
              return $store.dispatch('services/restartSystemService', { id: 'packetfence-mariadb', quiet: true })
          })
          .catch(error => {
            // Only show a notification in case of a failure
            const { response: { data: { message = '' } = {} } = {} } = error
            $store.dispatch('notification/danger', {
              icon: 'exclamation-triangle',
              url: message,
              message: i18n.t('An error occured while updating the general configuration.')
            })
            throw error
          })
      })
  }

  return {
    form,
    meta,
    schema,
    isLoading,
    onSave
  }
}

// @vue/component
export default {
  name: 'form-general',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
