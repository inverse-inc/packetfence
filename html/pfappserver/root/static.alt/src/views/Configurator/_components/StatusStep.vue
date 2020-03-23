<template>
  <base-step
    :name="$t('Confirmation')"
    icon="check">
    <passwords-view store-name="formPacketFence"/>
    <template v-slot:button-next>
      <pf-button-save :is-loading="isLoading" @click="completeConfigurator">
        {{ $t('Start PacketFence') }} <icon class="ml-1" name="play"></icon>
      </pf-button-save>
      <div class="d-block invalid-feedback text-muted" v-if="progressFeedback" v-text="progressFeedback"></div>
    </template>
  </base-step>
</template>

<script>
import BaseStep from './BaseStep'
import PasswordsView from './PasswordsView'
import pfButtonSave from '@/components/pfButtonSave'

export default {
  name: 'status-step',
  components: {
    BaseStep,
    PasswordsView,
    pfButtonSave
  },
  data () {
    return {
      advancedPromise: null,
      progressFeedback: null
    }
  },
  computed: {
    isLoading() {
      return this.$store.getters[`services/isLoading`] || this.$store.getters['$_bases/isLoading']
    }
  },
  methods: {
    completeConfigurator () {
      this.progressFeedback = this.$i18n.t('Applying configuration')
      this.$store.dispatch('services/restartSystemService', 'packetfence-config').then(() => {
        this.progressFeedback = this.$i18n.t('Enabling PacketFence')
        return this.$store.dispatch('services/updateSystemd', 'pf').then(() => {
          this.progressFeedback = this.$i18n.t('Starting PacketFence')
          return this.$store.dispatch('services/startService', 'pf').then(() => {
            this.progressFeedback = this.$i18n.t('Disabling Configurator')
            this.advancedPromise.then(data => {
              data.configurator = 'disabled'
              this.$store.dispatch('$_bases/updateAdvanced', data).then(() => {
                this.progressFeedback = this.$i18n.t('Redirecting to login page')
                setTimeout(() => {
                  this.$router.push({ name: 'login' })
                }, 2000)
              })
            })
          })
        })
      }).catch(err => {
        this.progressFeedback = null
      })
    }
  },
  created () {
    this.advancedPromise = this.$store.dispatch('$_bases/getAdvanced') // prefetch advanced configuration
  }
}
</script>
