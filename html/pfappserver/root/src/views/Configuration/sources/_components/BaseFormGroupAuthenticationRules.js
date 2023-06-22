import {computed, inject, provide, ref, watch} from '@vue/composition-api'
import {useNamespaceMetaAllowed} from '@/composables/useMeta'
import BaseFormGroupRules from './BaseFormGroupRules'
import {authenticationRuleActionsFromSourceType} from '../config'
import _ from 'lodash';
import useAdLdap
  from '@/views/Configuration/sources/_components/ldapCondition/useAdLdap';
import ProvidedKeys from '@/views/Configuration/sources/_components/ldapCondition/ProvidedKeys';
import useOpenLdap from '@/views/Configuration/sources/_components/ldapCondition/useOpenLdap';

const setup = () => {
  const sourceType = inject('sourceType', null)

  const actions = computed(() => authenticationRuleActionsFromSourceType(sourceType.value).map(type => {
    const {value: namespace} = type
    const options = useNamespaceMetaAllowed(`${namespace}_action`)
    return {...type, options}
  }))

  const form = computed(() => inject('form'))
  const ldapClient = getLdapClient(form.value)

  function connectionCheck() {
    ldapClient.checkConnection().then((connected) => {
      connectedToLdap.value = connected
    })
  }

  const debouncedConnectionCheck = _.debounce(connectionCheck, 1000)
  const connectedToLdap = ref(false)
  const ldapAttributes = ref([])
  const ldapAttributesLoading = ref(false)

  watch(form, debouncedConnectionCheck, {deep: true})

  watch(connectedToLdap, (newConnectionState, oldConnectionState) => {
    if (newConnectionState === true) {
      ldapAttributesLoading.value = true
      ldapClient.getAttributes().then((attributes) => {
        ldapAttributes.value = attributes
        ldapAttributesLoading.value = false
      })
    } else {
      ldapAttributes.value = []
    }
  })

  ldapClient.checkConnection().then((connected) => {connectedToLdap.value = connected})
  provide(ProvidedKeys.LdapAttributes, ldapAttributes)
  provide(ProvidedKeys.connectedToLdap, connectedToLdap)
  provide(ProvidedKeys.LdapAttributesLoading, ldapAttributesLoading)
  provide(ProvidedKeys.performSearch, ldapClient.performSearch)
  provide('actions', actions)

  return {form, connectedToLdap}
}



function getLdapClient(form) {
  switch (form.value.type) {
    // TODO form type should be an enum somewhere
    case "AD":
      return useAdLdap(form)
    // TODO add openLdap and eDirectory
    case "LDAP":
      return useOpenLdap(form)
  }
}

export default {
  name: 'base-form-group-authentication-rules',
  extends: BaseFormGroupRules,
  setup
}
