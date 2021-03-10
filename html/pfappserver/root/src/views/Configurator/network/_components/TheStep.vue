<template>
  <base-step ref="rootRef"
    :name="$t('Configure Network')"
    icon="project-diagram"
    :invalid-step="!isValid"
    :invalid-feedback="invalidFeedback"
    :is-loading="isLoading"
    :disable-navigation="disableNavigation"
    @next="onSave">
    <router-view ref="routerViewRef"></router-view>
  </base-step>
</template>
<script>
import BaseStep from '../../_components/BaseStep'

const components = {
  BaseStep
}

import { computed, ref } from '@vue/composition-api'
import { useQuerySelectorAll } from '@/composables/useDom'

const setup = (props, context) => {

  const { root: { $router } = {} } = context

  const rootRef = ref(null)
  const routerViewRef = ref(null)
  const disableNavigation = computed(() => (context.root.$route.name !== 'configurator-interfaces'))
  const isLoading = ref(false)

  // avoid having to pass events (state/invalidfeedback) up from deeply nested children within <router-view/>
  //  use DOM querySelectorAll with MutationObserver instead
  const _invalidNodes = useQuerySelectorAll(rootRef, '.form-group.is-invalid, .row.is-invalid')
  const isValid = computed(() => (!_invalidNodes.value || _invalidNodes.value.length === 0))
  const invalidFeedback = computed(() => (_invalidNodes.value && Array.prototype.slice.call(_invalidNodes.value)
    .map(node => node.querySelector('.invalid-feedback').textContent)
    .join(' ')
  ))

  const onSave = nextRoute => {
    isLoading.value = true
    routerViewRef.value.save().then(() => {
      $router.push(nextRoute)
    }).finally(() => {
      isLoading.value = false
    })
  }

  return {
    rootRef,
    routerViewRef,
    disableNavigation,
    isLoading,
    isValid,
    invalidFeedback,
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
