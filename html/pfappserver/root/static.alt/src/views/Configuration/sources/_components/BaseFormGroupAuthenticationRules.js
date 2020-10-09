import { computed, inject, provide } from '@vue/composition-api'
import { useNamespaceMetaAllowed } from '@/composables/useMeta'
import BaseFormGroupRules from './BaseFormGroupRules'
import { authenticationRuleActionsFromSourceType } from '../config'

const setup = () => {
  const sourceType = inject('sourceType', null)

  const actions = computed(() => authenticationRuleActionsFromSourceType(sourceType.value).map(type => {
    const { value: namespace } = type
    const options = useNamespaceMetaAllowed(`${namespace}_action`).value
    return { ...type, options }
  }))
  provide('actions', actions)
}

export default {
  name: 'base-form-group-authentication-rules',
  extends: BaseFormGroupRules,
  setup
}
