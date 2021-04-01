<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Interfaces & Networks'"></h4>
    </b-card-header>
    <div class="card-body mb-3">
      <b-table class="table-clickable"
        :items="interfaces"
        :fields="fieldsInterface"
        :sort-by="'id'"
        :sort-desc="false"
        :sort-compare="sortCompareInterface"
        :hover="interfaces && interfaces.length > 0"
        @row-clicked="onRowClickInterface"
        show-empty
        responsive
        fixed
        sort-icon-left
      >
        <template v-slot:empty>
          <pf-empty-table :is-loading="isLoading">{{ $t('No interfaces found') }}</pf-empty-table>
        </template>
        <template v-slot:cell(is_running)="{ item }">
          <toggle-status :value="item.is_running" 
          :disabled="item.type === 'management' || isLoading"
          :item="item" />
        </template>
        <template v-slot:cell(id)="item">
          <span class="text-nowrap mr-2">{{ item.item.name }}</span>
          <b-badge v-if="item.item.vlan" variant="secondary">VLAN {{ item.item.vlan }}</b-badge>
        </template>
        <!-- <template v-slot:cell(additional_listening_daemons)="item">
          <b-badge v-for="(daemon, index) in item.item.additional_listening_daemons" :key="index" class="mr-1" variant="secondary">{{ daemon }}</b-badge>
        </template> -->
        <template v-slot:cell(ipaddress)="{ item }">
          <ip>{{ item.ipaddress }}</ip><ip v-if="item.netmask" class="text-black-50">/{{ item.netmask }}</ip>
          <ip>{{ item.ipv6_address }}</ip><ip v-if="item.ipv6_prefix" class="text-black-50">{{ item.ipv6_prefix }}</ip>
        </template>
        <template v-slot:cell(type)="{ item }">
          {{ item.type }}
          <b-badge v-for="(daemon, index) in item.additional_listening_daemons" :key="index" class="mr-1" variant="secondary">{{ daemon }}</b-badge>
        </template>
        <!-- <template v-slot:cell(high_availability)="item">
          <icon name="circle" :class="{ 'text-success': item.item.high_availability === 1, 'text-danger': item.item.high_availability === 0 }"></icon>
        </template> -->
        <template v-slot:cell(buttons)="{ item }">
          <span v-if="item.vlan"
            class="float-right text-nowrap"
          >
            <pf-button-delete size="sm" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete VLAN?')" @on-delete="removeInterface(item)" reverse/>
            <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isLoading" @click.stop.prevent="cloneInterface(item)">{{ $t('Clone') }}</b-button>
          </span>
          <span v-else
            class="float-right text-nowrap"
          >
            <b-button size="sm" variant="outline-primary" class="mr-1" :disabled="isLoading" @click.stop.prevent="addVlanInterface(item)">{{ $t('New VLAN') }}</b-button>
          </span>
        </template>
      </b-table>

      <b-row v-if="managementTypeCount === 0 || isDetecting"
        align-v="center" class="is-invalid">
        <b-col cols="6">
          <div class="invalid-feedback d-block">{{ $t('At least one Interface must be of Type "management".') }}</div>
        </b-col>
        <b-col cols="6" class="text-right">
           <base-button-save
             class="float-right"
             :is-loading="isDetecting"
             @click="detectManagementInterface"
           >
             {{ $t('Detect Management Interface') }}
           </base-button-save>          
         </b-col>
      </b-row>

      <hr/>

      <base-form
        :form="form"
        :schema="schema"
        :is-loading="isLoading"
      >
        <form-group-gateway namespace="gateway"
          :column-label="$i18n.t('Default Gateway')"
        />

        <form-group-hostname namespace="hostname"
          :column-label="$i18n.t('Server Hostname')"
          :text="rebootAlert"
        />

        <form-group-dns-servers namespace="dns_servers"
          :column-label="$i18n.t('DNS Servers')"
          :taggable="true"
          :tag-placeholder="$t('Click to add host')"
        />
      </base-form>
    </div>
  </b-card>
</template>

<script>
import {
  BaseButtonSave,
  BaseForm,
  BaseFormGroupChosenMultiple,
  BaseFormGroupInput
} from '@/components/new/'
import pfButton from '@/components/pfButton'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfEmptyTable from '@/components/pfEmptyTable'
import { ToggleStatus } from '@/views/Configuration/networks/interfaces/_components/'

const components = {
  BaseButtonSave,
  BaseForm,

  FormGroupGateway:    BaseFormGroupInput,
  FormGroupHostname:   BaseFormGroupInput,
  FormGroupDnsServers: BaseFormGroupChosenMultiple,
  pfButton,
  pfButtonDelete,
  pfEmptyTable,
  ToggleStatus
}

import { computed, inject, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import network from '@/utils/network'
import yup from '@/utils/yup'
import {
  typeFormatter,
  sortColumns
} from '@/views/Configuration/_config/interface'

const fieldsInterface = [
  {
    key: 'is_running',
    label: i18n.t('Status'),
    visible: true
  },
  {
    key: 'id',
    label: i18n.t('Logical Name'),
    required: true,
    sortable: true,
    visible: true,
    sort: sortColumns.id
  },
  {
    key: 'ipaddress',
    label: i18n.t('IP Address'),
    sortable: true,
    visible: true,
    sort: sortColumns.ipaddress
  },
  {
    key: 'network',
    label: i18n.t('Default Network'),
    sortable: true,
    visible: true,
    sort: sortColumns.network
  },
  {
    key: 'type',
    label: i18n.t('Type'),
    visible: true,
    formatter: typeFormatter
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]
const sortCompareInterface = (itemA, itemB, key, sortDesc) => {
  if (fieldsInterface.filter(field => (field.key === key && field.sort)).length > 0) {
    return fieldsInterface
      .find(field => (field.key === key && field.sort))
      .sort(itemA, itemB, sortDesc, this) // custom sort
  }
  return null // default sort
}

const setup = (props, context) => {

const { root: { $router, $store } = {} } = context

  const state = inject('state') // Configurator
  // form defaults from state.network
  const { network: _network = {} } = state.value
  const form = ref({ ..._network }) // default form

  if (!form.value.gateway)
    $store.dispatch('system/getGateway').then(gateway => (form.value = { ...form.value, gateway }))

  if (!form.value.hostname)
    $store.dispatch('system/getHostname').then(hostname => (form.value = { ...form.value, hostname }))

  if (!form.value.dns_servers)
    $store.dispatch('system/getDnsServers').then(dns_servers => (form.value = { ...form.value, dns_servers }))

  const schema = computed(() => {
    return yup.object({
      gateway: yup.string().nullable().required(i18n.t('Gateway required.')),
      hostname: yup.string().nullable().required(i18n.t('Hostname required.')),
      dns_servers: yup.array().ensure().required(i18n.t('DNS server(s) required.')).of(yup.string().nullable())
    })
  })

  const isDetecting = ref(false)
  const isLoading = computed(() => $store.getters['$_interfaces/isLoading'])
  
  const hostname = computed(() => $store.state.system.hostname)

  $store.dispatch(`$_interfaces/all`)
  const interfaces = computed(() => $store.getters['$_interfaces/cacheFlattened']
    .map(i => {
      return (i.vlan)
        ? { ...i, _rowVariant: 'secondary' } // set table row variant on vlans
        : i
    })
  )

  const rebootAlert = computed(() => ((isLoading.value || form.value.hostname === hostname.value) 
    ? null
    : `<span class="text-warning">${i18n.t('Please reboot the server at the end of the configuration wizard to apply changes.')}</span>`
  ))

  const managementTypeCount = computed(() => interfaces.value.filter(i => i.type === 'management').length)

  const detectManagementInterface = () => {
    if (managementTypeCount.value === 0) {
      isDetecting.value = true
      // No interface is of type management -- force one
      let management_interface = interfaces.value.find(i => {
        return i.network && i.netmask && network.ipv4InSubnet(form.value.gateway, network.ipv4NetmaskToSubnet(i.network, i.netmask))
      })
      if (!management_interface) {
        management_interface = interfaces.value.find(i => {
          return i.address && i.address.length > 0
        })
      }
      if (management_interface) {
        management_interface.type = 'management'
        $store.dispatch('notification/danger', {
          icon: 'exclamation-triangle',
          message: i18n.t('Management interface <code>{id}</code> found.', management_interface)
        })          
        $store.dispatch('$_interfaces/updateInterface', management_interface)
          .finally(() => {
            isDetecting.value = false
          })
      }
      else {
        $store.dispatch('notification/danger', {
          icon: 'exclamation-triangle',
          message: i18n.t('Management interface not found.')
        })
        isDetecting.value = false          
      }
    }
  }

  const cloneInterface = (item) => {
    state.value.network = form.value // stash state
    $router.push({ name: 'configurator-cloneInterface', params: { id: item.id } })
  }
  const removeInterface = (item) => {
    $store.dispatch(`$_interfaces/deleteInterface`, item.id)
  }
  const addVlanInterface = (item) => {
    state.value.network = form.value // stash state
    $router.push({ name: 'configurator-newInterface', params: { id: item.id } })
  }
  const onRowClickInterface = (item) => {
    state.value.network = form.value // stash state
    $router.push({ name: 'configurator-interface', params: { id: item.id } })
  }

  const onSave = ()  => {
    const { gateway, hostname, dns_servers } = form.value
    return Promise.all([
      $store.dispatch('system/getGateway').then(initialGateway => {
        if (initialGateway === gateway) {
          return Promise.resolve() // no change
        } else {
          return $store.dispatch('system/setGateway', { quiet: true, gateway })
        }
      }).catch(error => {
        // Only show a notification in case of a failure
        const { response: { data: { message = '' } = {} } = {} } = error
        $store.dispatch('notification/danger', {
          icon: 'exclamation-triangle',
          url: message,
          message: i18n.t('An error occured while updating the default gateway.')
        })
        throw error
      }),
      $store.dispatch('system/getHostname').then(initialHostname => {
        if (initialHostname === hostname) {
          return Promise.resolve()
        } else {
          return $store.dispatch('system/setHostname', { quiet: true, hostname })
        }
      }).catch(error => {
        // Only show a notification in case of a failure
        const { response: { data: { message = '' } = {} } = {} } = error
        $store.dispatch('notification/danger', {
          icon: 'exclamation-triangle',
          url: message,
          message: i18n.t('An error occured while updating the hostname.')
        })
        throw error
      }),
      $store.dispatch('system/setDnsServers', { quiet: true, dns_servers })
        .catch(error => {
          // Only show a notification in case of a failure
          const { response: { data: { message = '' } = {} } = {} } = error
          $store.dispatch('notification/danger', {
            icon: 'exclamation-triangle',
            url: message,
            message: i18n.t('An error occured while updating the DNS servers.')
          })
          throw error
        })
    ])
    .then(() => state.value.network = { ...state.value.network, ...form.value })
  }

  return {
    fieldsInterface,
    sortCompareInterface,

    form,
    schema,

    isDetecting,
    isLoading,
    hostname,
    interfaces,
    rebootAlert,
    managementTypeCount,
    detectManagementInterface,
    cloneInterface,
    removeInterface,
    addVlanInterface,
    onRowClickInterface,
    onSave
  }
}

// @vue/component
export default {
  name: 'the-list',
  components,
  setup
}
</script>
