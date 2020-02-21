<template>
  <base-step
    :name="$t('Configure Network')"
    icon="project-diagram">
    <router-view></router-view>
  </base-step>
</template>

<script>
import BaseStep from './BaseStep'

export default {
  name: 'network-step',
  components: {
    BaseStep
  }
}
</script>
