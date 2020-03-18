<template>
  <base-step
    :name="$t('Configure Network')"
    icon="project-diagram"
    :invalid-step="invalidStep"
    :invalid-feedback="invalidFeedback"
    :is-loading="isLoading"
    :disable-navigation="disableNavigation"
    @next="save">
    <router-view ref="interfaceslist"></router-view>
  </base-step>
</template>

<script>
import BaseStep from './BaseStep'
import {
  networkValidators
} from '../_config/interface'

export default {
  name: 'network-step',
  components: {
    BaseStep
  },
  data () {
    return {
      isLoading: false
    }
  },
  computed: {
    formNetwork () {
      return this.$store.getters['formNetwork/$form']
    },
    interfaces () {
      return this.$store.state.$_interfaces.interfaces // Rely on InterfacesList to fetch the interfaces
    },
    invalidStep () {
      return this.$store.getters['formNetwork/$formInvalid']
    },
    invalidFeedback () {
      return this.$store.getters['formNetwork/$feedbackNS']('management_type')
    },
    managementTypeCount () {
      return this.interfaces.filter(i => i.type === 'management').length
    },
    disableNavigation () {
      return this.$route.name !== 'configurator-interfaces'
    }
  },
  methods: {
    save (nextRouteName) {
      const { interfaceslist } = this.$refs
      this.isLoading = true
      interfaceslist.save().then(() => {
        this.$router.push({ name: nextRouteName })
      }).finally(() => {
        this.isLoading = false
      })
    }
  },
  created () {
    this.$store.dispatch('formNetwork/setForm', {}).then(() => {
      this.$store.dispatch('formNetwork/setFormValidations', networkValidators)
      this.$watch('managementTypeCount', () => {
          this.$set(this.formNetwork, 'management_type', this.managementTypeCount)
        },
        { immediate: true }
      )
    })
  }
}
</script>
