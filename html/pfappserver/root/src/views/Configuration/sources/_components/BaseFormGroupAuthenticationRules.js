import {computed, inject, provide, ref} from '@vue/composition-api'
import { useNamespaceMetaAllowed } from '@/composables/useMeta'
import BaseFormGroupRules from './BaseFormGroupRules'
import { authenticationRuleActionsFromSourceType } from '../config'
import fetchLdapAttributesAD
  from '@/views/Configuration/sources/_components/ldapCondition/fetchLdapAttributesAD';

const setup = () => {
  const sourceType = inject('sourceType', null)

  const actions = computed(() => authenticationRuleActionsFromSourceType(sourceType.value).map(type => {
    const { value: namespace } = type
    const options = useNamespaceMetaAllowed(`${namespace}_action`)
    return { ...type, options }
  }))

  const ldapAttributes = ref([])
  getAttributesByForm(inject('form')).then((attributes) => {
    ldapAttributes.value = attributes
  })
  provide('ldapAttributes', ldapAttributes)
  provide('actions', actions)
}

function getAttributesByForm(form){
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
