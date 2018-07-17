<template>
        <b-row>
            <b-col cols="12" md="3" xl="2" class="bd-sidebar">
                <div class="bd-search d-flex align-items-center">
                    <b-form-input type="text" :placeholder="$t('Filter')"></b-form-input>
                    <b-btn class="bd-search-docs-toggle d-md-none p-0 ml-3" aria-controls="bd-docs-nav">=</b-btn>
                </div>
                <b-collapse is-nav class="bd-links" id="bd-docs-nav">
                    <div class="bd-toc-item active">
                        <b-nav vertical class="bd-sidenav">
                            <div class="bd-toc-link" v-t="'Nodes'"></div>
                            <b-nav-item to="/nodes/search" replace>{{ $t('Search') }}</b-nav-item>
                            <b-nav-item to="/nodes/create" replace>{{ $t('Create') }}</b-nav-item>
                            <hr/>
                            <div class="bd-toc-link" v-t="'Standard Searches'"></div>
                            <b-nav-item to="/nodes/search/openviolations" replace>{{ $t('Open Violations') }}</b-nav-item>
                            <b-nav-item to="/nodes/search/closedviolations" replace>{{ $t('Closed Violations') }}</b-nav-item>

                            <!-- Standard Searches > Switch Roles -->
                            <div class="bd-toc-link" v-b-toggle="'accordionRoles'">
                              {{ $t('Roles') }}
                              <icon class="when-opened float-right mt-1" name="caret-down"></icon>
                              <icon class="when-closed float-right mt-1" name="caret-right"></icon>
                            </div>
                            <b-collapse id="accordionRoles" ref="accordionRoles" is-nav>
                                <b-nav-item v-for="role in roles" :key="role.name" :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"category_id","op":"equals","value":role.category_id}]}]})}}' replace>{{role.name}}</b-nav-item>
                            </b-collapse>

                            <!-- Standard Searches > OS -->
                            <div class="bd-toc-link" v-b-toggle="'accordionOs'">
                              {{ $t('OS') }}
                              <icon class="when-opened float-right mt-1" name="caret-down"></icon>
                              <icon class="when-closed float-right mt-1" name="caret-right"></icon>
                            </div>
                            <b-collapse id="accordionOs" ref="accordionOs" is-nav>
                                <b-nav-item :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"Windows OS"}]}]})}}' replace>{{ $t('Windows') }}</b-nav-item>
                                <b-nav-item :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"Linux OS"}]}]})}}' replace>{{ $t('Linux') }}</b-nav-item>
                                <b-nav-item :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"Mac OS X or macOS"}]}]})}}' replace>{{ $t('MacOS') }}</b-nav-item>
                                <b-nav-item :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"Windows Phone OS"},{"field":"device_class","op":"equals","value":"WebOS"},{"field":"device_class","op":"equals","value":"iOS"},{"field":"device_class","op":"equals","value":"Palm OS"},{"field":"device_class","op":"equals","value":"Android OS"},{"field":"device_class","op":"equals","value":"watchOS"},{"field":"device_class","op":"equals","value":"Phone, Tablet or Wearable"},{"field":"mac","op":"equals","value":"BlackBerry OS"}]}]})}}' replace>{{ $t('Mobile Devices') }}</b-nav-item>
                                <b-nav-item :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"Gaming Console"}]}]})}}' replace>{{ $t('Gaming Console') }}</b-nav-item>
                                <b-nav-item :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"device_class","op":"equals","value":"VoIP Device"}]}]})}}' replace>{{ $t('VoIP Device') }}</b-nav-item>
                            </b-collapse>
                            <!-- Standard Searches > Switch Groups -->
                            <div class="bd-toc-link" v-b-toggle="'accordionSwitchGroups'">
                              {{ $t('Switch Groups') }}
                              <icon class="when-closed float-right mt-1" name="caret-right"></icon>
                              <icon class="when-opened float-right mt-1" name="caret-down"></icon>
                            </div>
                            <b-collapse id="accordionSwitchGroups" ref="accordionSwitchGroups" is-nav>
                              <div v-for="switchGroup in switchGroups" :key="switchGroup.id">
                                <div class="bd-toc-link" v-b-toggle="`accordionSwitchGroup${switchGroup.group}`">
                                  <icon class="when-closed mt-1" name="circle"></icon>
                                  <icon class="when-opened mt-1" name="dot-circle"></icon>
                                  {{ switchGroup.group }}
                                </div>
                                <b-collapse :id="`accordionSwitchGroup${switchGroup.group}`" :ref="`accordionSwitchGroup${switchGroup.group}`" is-nav>
                                  <b-nav-item v-for="sw in switchGroup.switches" :key="sw.id" v-if="sw.id !== 'default'" :to='{"path":"search", "query":{"query":JSON.stringify({"op":"and","values":[{"op":"or","values":[{"field":"locationlog.switch","op":"equals","value":getIpFromCIDR(sw.id)}]}]})}}' replace>
                                    <blockquote class="mb-0">
                                      {{ sw.id }}<br/>
                                      {{ sw.description }}
                                    </blockquote>
                                  </b-nav-item>
                                </b-collapse>
                              </div>
                            </b-collapse>
                          </b-nav>
                        <pf-saved-search :storeName="'$_' + this.$options.name.toLowerCase()" :routeName="this.$options.name.toLowerCase()"/>
                    </div>
                </b-collapse>
            </b-col>
            <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
                <transition name="slide-bottom">
                    <router-view></router-view>
                </transition>
            </b-col>
        </b-row>
</template>

<script>
import pfMixinSavedSearch from '@/components/pfMixinSavedSearch'

export default {
  name: 'Nodes',
  mixins: [
    pfMixinSavedSearch
  ],
  components: {
    'pf-saved-search': pfMixinSavedSearch
  },
  computed: {
    roles () {
      return this.$store.state.config.roles
    },
    switches () {
      return this.$store.state.config.switches
    },
    switchGroups () {
      return this.$store.getters['config/groupedSwitches']
    }
  },
  methods: {
    getIpFromCIDR (cidr) {
      return cidr.split('/', 1)[0] || cidr
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
    this.$store.dispatch('config/getSwitches')
  }
}
</script>

<style>
.collapsed > svg.when-opened,
:not(.collapsed) > svg.when-closed {
  display: none;
}
</style>
