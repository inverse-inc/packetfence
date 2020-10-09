import { computed, inject, provide } from '@vue/composition-api'
import { useNamespaceMetaAllowed } from '@/composables/useMeta'
import BaseFormGroupRules from './BaseFormGroupRules'
import { administrationRuleActionsFromSourceType } from '../config'

const setup = () => {
  const sourceType = inject('sourceType', null)

  const actions = computed(() => administrationRuleActionsFromSourceType(sourceType.value).map(type => {
    const { value: namespace } = type
    const options = useNamespaceMetaAllowed(`${namespace}_action`).value
    return { ...type, options }
  }))
  provide('actions', actions)
}

export default {
  name: 'base-form-group-administration-rules',
  extends: BaseFormGroupRules,
  setup
}
