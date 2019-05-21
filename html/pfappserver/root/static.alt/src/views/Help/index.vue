<template>
    <b-row class="justify-content-md-center mt-3">
        <b-col sm="3" class="text-right">
          <b-card no-body>
            <b-card-body>
              <pf-form-row :column-label="$t('Version')">
                PacketFence {{ version }}
              </pf-form-row>
              <pf-form-row :column-label="$t('Server')">
                {{ hostname }}
              </pf-form-row>
            </b-card-body>
            <b-card-footer>
              <b-button href="https://packetfence.org/support.html#/commercial" target="_blank">{{ $t('Support Inquiry') }}</b-button>
            </b-card-footer>
          </b-card>
          <b-link href="https://inverse.ca/"><img alt="Inverse" src="/static/img/inverse.small.png"></b-link>
        </b-col>
        <b-col sm="7">
          <b-card no-body>
            <b-card-header>
              <h4 class="m-0">{{ $t('Documentation') }}</h4>
            </b-card-header>
            <b-card-body>
              <b-list-group>
                <b-list-group-item v-for="[name, path] in guides" :key="path"
                  :href="`/static/doc/PacketFence_${path}.html`" target="_blank">{{ name }}</b-list-group-item>
              </b-list-group>
            </b-card-body>
          </b-card>
        </b-col>
    </b-row>
</template>

<script>
import pfFormRow from '@/components/pfFormRow'

export default {
  name: 'Help',
  components: {
    pfFormRow
  },
  data () {
    return {
      guides: [
        [this.$i18n.t('Installation Guide'), 'Installation_Guide'],
        [this.$i18n.t('Network Devices Configuration Guide'), 'Network_Devices_Configuration_Guide'],
        [this.$i18n.t('Clustering Guide'), 'Clustering_Guide'],
        [this.$i18n.t('Developer\'s Guide'), 'Developers_Guide']
      ]
    }
  },
  computed: {
    version () {
      return this.$store.getters['system/version']
    },
    hostname () {
      return this.$store.getters['system/hostname']
    }
  }
}
</script>
