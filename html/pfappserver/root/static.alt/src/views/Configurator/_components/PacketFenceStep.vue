<template>
  <base-step
    :name="$t('Configure PacketFence')"
    icon="cogs"
    :invalid-step="invalidStep"
    :invalid-feedback="invalidFeedback"
    :is-loading="isLoading"
    @next="save">
    <database-view form-store-name="formPacketFence" ref="database" />
    <general-view class="mt-3" form-store-name="formPacketFence" ref="general" />
    <alerting-view class="mt-3" form-store-name="formPacketFence" ref="alerting" />
    <administrator-view class="mt-3" form-store-name="formPacketFence" ref="administrator" />
  </base-step>
</template>

<script>
import BaseStep from './BaseStep'
import DatabaseView from './DatabaseView'
import GeneralView from './GeneralView'
import AlertingView from './AlertingView'
import AdministratorView from './AdministratorView'

export default {
  name: 'packetfence-step',
  components: {
    BaseStep,
    DatabaseView,
    GeneralView,
    AlertingView,
    AdministratorView
  },
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
    save (nextRouteName) {
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
        this.$router.push({ name: nextRouteName })
      }).finally(() => {
        this.isLoading = false
      })
    }
  }
}
</script>
