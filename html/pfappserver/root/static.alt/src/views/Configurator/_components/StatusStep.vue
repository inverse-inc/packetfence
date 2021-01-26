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

// @vue/component
export default {
  name: 'status-step',
  components: {
    BaseStep,
    PasswordsView,
    pfButtonSave
  },
  data () {
    return {
      isLoading: false,
      advancedPromise: null,
      progressFeedback: null
    }
  },
  methods: {
    completeConfigurator () {
      this.isLoading = true
      this.progressFeedback = this.$i18n.t('Applying configuration')
      this.$store.dispatch('services/restartSystemService', 'packetfence-config').then(() => {
        this.progressFeedback = this.$i18n.t('Enabling PacketFence')
        return this.$store.dispatch('services/updateSystemd', 'pf').then(() => {
          this.progressFeedback = this.$i18n.t('Starting PacketFence')
          return this.$store.dispatch('services/restartService', { quiet: true, id: 'haproxy-admin' }).catch(e => e).finally(() => {
            const haproxyReady = new Promise((resolve, reject) => {
              let count = 10 // try to reconnect at most 10 times
              const pingHaproxy = () => {
                this.$store.dispatch('system/getHostname', { cache: false }).then(resolve).catch(() => {
                  count--
                  if (count > 0) {
                    setTimeout(pingHaproxy, 2000)
                  } else {
                    reject()
                  }
                })
              }
              pingHaproxy()
            })
            return haproxyReady.then(() => {
              return this.$store.dispatch('services/startService', 'pf').then(() => {
                this.progressFeedback = this.$i18n.t('Disabling Configurator')
                return this.advancedPromise.then(data => {
                  data.configurator = 'disabled'
                  return this.$store.dispatch('$_bases/updateAdvanced', data).then(() => {
                    this.progressFeedback = this.$i18n.t('Redirecting to login page')
                    setTimeout(() => {
                      this.$router.push({ name: 'login' })
                    }, 2000)
                  })
                })
              })
            })
          })
        })
      }).catch(() => {
        this.progressFeedback = null
      }).finally(() => {
        this.isLoading = false
      })
    }
  },
  created () {
    this.advancedPromise = this.$store.dispatch('$_bases/getAdvanced') // prefetch advanced configuration
  }
}
</script>
