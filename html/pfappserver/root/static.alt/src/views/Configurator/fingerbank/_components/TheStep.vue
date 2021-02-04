<template>
  <base-step ref="rootRef"
    :name="$t('Fingerbank on-boarding')"
    icon="fingerprint"
    :invalid-step="!isValid"
    :invalid-feedback="invalidFeedback"
    @next="onSave">
    <form-fingerbank ref="fingerbankRef" />
  </base-step>
</template>
<script>
import BaseStep from '../../_components/BaseStep'
import FormFingerbank from './FormFingerbank'

const components = {
  BaseStep,

  FormFingerbank
}

import { computed, ref } from '@vue/composition-api'
import { useQuerySelectorAll } from '@/composables/useDom'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const { root: { $router } = {} } = context

  const rootRef = ref(null)

  // avoid having to pass events (state/invalidfeedback) up from deeply nested children within <router-view/>
  //  use DOM querySelectorAll with MutationObserver instead
  const _invalidNodes = useQuerySelectorAll(rootRef, '.form-group.is-invalid, .row.is-invalid')
  const isValid = computed(() => (!_invalidNodes.value || _invalidNodes.value.length === 0))
  const invalidFeedback = computed(() => (_invalidNodes.value && Array.prototype.slice.call(_invalidNodes.value)
    .map(node => node.querySelector('.invalid-feedback').textContent)
    .join(' ')
  ))

  const progressFeedback = ref(null)
  const onSave = nextRoute => {
    progressFeedback.value = i18n.t('Loading next step')
    $router.push(nextRoute)
  }

  return {
    rootRef,
    isValid,
    invalidFeedback,
    progressFeedback,
    onSave
  }
}


// @vue/component
export default {
  name: 'the-step',
  components,
  setup
}
</script>
