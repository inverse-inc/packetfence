<template>
  <base-step
    :name="$t('Configure PacketFence')"
    icon="cogs"
    :invalid-step="invalidStep"
    :invalid-feedback="invalidFeedback"
    :is-loading="isLoading"
    @next="save">
    <database-view ref="database" />
    <general-view ref="general" class="mt-3" />
    <alerting-view ref="alerting" class="mt-3" />
    <administrator-view ref="administrator" class="mt-3" />
  </base-step>
</template>
<script>
import BaseStep from './BaseStep'
import DatabaseView from './DatabaseView'
import GeneralView from './GeneralView'
import AlertingView from './AlertingView'
import AdministratorView from './AdministratorView'

const components = {
  BaseStep,
  DatabaseView,
  GeneralView,
  AlertingView,
  AdministratorView
}

// @vue/component
export default {
  name: 'packetfence-step',
  components,
  data () {
    return {
      isLoading: false
    }
  },
  computed: {
    invalidStep () {
      return this.$store.getters['formPacketFence/$formInvalid']
    },
    invalidFeedback () {
      return [
        this.$store.getters['formPacketFence/$feedbackNS']('database.database_exists'),
        this.$store.getters['formPacketFence/$feedbackNS']('database.user_is_valid')
      ].join(' ')
    }
  },
  methods: {
    save (nextRoute) {
      const { database, general, alerting, administrator } = this.$refs
      this.isLoading = true
      database.save().then(() => {
        return Promise.all([
          general.save(),
          alerting.save()
        ]).then(() => {
          return administrator.save()
        })
      }).then(() => {
        this.$router.push(nextRoute)
      }).finally(() => {
        this.isLoading = false
      })
    }
  }
}
</script>
