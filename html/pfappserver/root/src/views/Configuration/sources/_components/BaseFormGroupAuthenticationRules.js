import {computed, inject, provide, ref} from '@vue/composition-api'
import {useNamespaceMetaAllowed} from '@/composables/useMeta'
import BaseFormGroupRules from './BaseFormGroupRules'
import {authenticationRuleActionsFromSourceType} from '../config'
import fetchLdapAttributesAD
  from '@/views/Configuration/sources/_components/ldapCondition/fetchLdapAttributesAD';
import ProvidedKeys from '@/views/Configuration/sources/_components/ldapCondition/ProvidedKeys';

const setup = () => {
  const sourceType = inject('sourceType', null)

  const actions = computed(() => authenticationRuleActionsFromSourceType(sourceType.value).map(type => {
    const {value: namespace} = type
    const options = useNamespaceMetaAllowed(`${namespace}_action`)
    return {...type, options}
  }))

  const ldapAttributes = ref([])
  const ldapAttributesError = ref(null)
  getAttributesByForm(inject('form')).then((attributes) => {
    ldapAttributes.value = attributes
  }).catch((error) => {
    if (error.response?.status.toString().startsWith("4")) {
      ldapAttributesError.value = error.message
    }
  })
  provide(ProvidedKeys.LdapAttributes, ldapAttributes)
  provide(ProvidedKeys.LdapAttributesError, ldapAttributesError)
  provide('actions', actions)
}

function getAttributesByForm(form) {
  switch (form.value.type) {
    // TODO form type should be an enum somewhere
    case "AD":
      return fetchLdapAttributesAD(form.value.id)
    // TODO add openLdap and eDirectory
    default:
      return new Promise(() => [])
  }
}

export default {
  name: 'base-form-group-authentication-rules',
  extends: BaseFormGroupRules,
  setup
}
