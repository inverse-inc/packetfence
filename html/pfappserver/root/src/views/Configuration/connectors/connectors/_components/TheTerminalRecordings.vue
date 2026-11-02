<template>
  <div class="border-top">
    <div class="card-body">
      <b-row align-v="center" class="mb-2">
        <b-col>
          <h6 class="mb-0">
            {{ $i18n.t('Terminal Session Recordings') }}
            <b-badge v-if="recordings.length" variant="light" class="border ml-2">{{ recordings.length }}</b-badge>
          </h6>
          <small class="text-muted">{{ $i18n.t('Every terminal session opened on this connector is recorded (asciicast) on the connector host. Replay it here or download the file to keep it.') }}</small>
        </b-col>
        <b-col cols="auto">
          <b-button size="sm" variant="outline-secondary" :disabled="isLoading" @click="refresh">
            <icon name="sync" :spin="isLoading" class="mr-1" />{{ $i18n.t('Refresh') }}
          </b-button>
        </b-col>
      </b-row>

      <b-alert :show="!!error" variant="danger" class="mb-2 py-1 small">{{ error }}</b-alert>

      <b-table-simple v-if="recordings.length" small hover class="mb-0">
        <b-thead>
          <b-tr>
            <b-th>{{ $i18n.t('Started') }}</b-th>
            <b-th>{{ $i18n.t('Admin') }}</b-th>
            <b-th>{{ $i18n.t('Duration') }}</b-th>
            <b-th>{{ $i18n.t('Size') }}</b-th>
            <b-th>{{ $i18n.t('Session') }}</b-th>
            <b-th class="text-right"></b-th>
          </b-tr>
        </b-thead>
        <b-tbody>
          <b-tr v-for="recording in recordings" :key="recording.name">
            <b-td class="text-nowrap">
              {{ formatDate(recording.started_at) }}
              <b-badge v-if="recording.in_progress" variant="success" class="ml-1">{{ $i18n.t('live') }}</b-badge>
            </b-td>
            <b-td>{{ recording.admin_user || '-' }}</b-td>
            <b-td class="text-nowrap">{{ formatDuration(recording.duration_seconds) }}</b-td>
            <b-td class="text-nowrap">{{ formatBytes(recording.size) }}</b-td>
            <b-td class="text-monospace small text-muted" :title="recording.name">{{ recording.session }}</b-td>
            <b-td class="text-right text-nowrap">
              <b-button size="sm" variant="outline-primary" class="py-0 mr-1"
                :disabled="busy === recording.name" @click="play(recording)">
                <icon v-if="busy === recording.name && busyAction === 'play'" name="circle-notch" spin class="mr-1" />
                <icon v-else name="play" class="mr-1" />{{ $i18n.t('Replay') }}
              </b-button>
              <b-button size="sm" variant="outline-secondary" class="py-0"
                :disabled="busy === recording.name" @click="download(recording)">
                <icon v-if="busy === recording.name && busyAction === 'download'" name="circle-notch" spin class="mr-1" />
                <icon v-else name="download" class="mr-1" />{{ $i18n.t('Download') }}
              </b-button>
            </b-td>
          </b-tr>
        </b-tbody>
      </b-table-simple>
      <p v-else-if="!isLoading && !error" class="text-muted mb-0">{{ $i18n.t('No terminal session has been recorded on this connector yet.') }}</p>
    </div>

    <b-modal v-model="showPlayer" size="xl" centered scrollable body-class="p-0 bg-dark"
      :title="playerTitle" @hidden="disposePlayer">
      <div ref="playerRef" class="pf-asciinema"></div>
      <template #modal-footer="{ hide }">
        <small v-if="playing" class="text-muted mr-auto">
          {{ playing.name }}
          <span v-if="playing.in_progress" class="ml-2">{{ $i18n.t('This session is still running: the replay stops at the last event written so far.') }}</span>
        </small>
        <b-button variant="outline-secondary" :disabled="!playing" @click="download(playing)">
          <icon name="download" class="mr-1" />{{ $i18n.t('Download') }}
        </b-button>
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Close') }}</b-button>
      </template>
    </b-modal>
  </div>
</template>
<script>
import { nextTick, onBeforeUnmount, onMounted, ref } from '@vue/composition-api'
import * as AsciinemaPlayer from 'asciinema-player'
import 'asciinema-player/dist/bundle/asciinema-player.css'
import i18n from '@/utils/locale'
import { useDownload } from '@/composables/useDownload'
import api from '../_api'

export const props = {
  id: {
    type: String
  }
}

export const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const recordings = ref([])
  const error = ref(null)
  const isLoading = ref(false)
  const busy = ref(null)
  const busyAction = ref(null)
  const showPlayer = ref(false)
  const playerTitle = ref('')
  const playing = ref(null)
  const playerRef = ref(null)
  let player = null

  const errorMessage = (err, fallback) => {
    const { response: { data } = {} } = err || {}
    if (data && typeof data === 'object' && data.message)
      return data.message
    if (typeof data === 'string' && data.trim())
      return data.trim()
    return fallback
  }

  const refresh = () => {
    if (!props.id)
      return
    isLoading.value = true
    api.terminalRecordings(props.id).then(response => {
      recordings.value = Array.isArray(response.recordings) ? response.recordings : []
      error.value = null
    }).catch(err => {
      recordings.value = []
      error.value = errorMessage(err, i18n.t('Unable to list the terminal recordings of the remote connector.'))
    }).finally(() => {
      isLoading.value = false
    })
  }

  // fetch downloads one recording as text (asciicast: one JSON document per
  // line) through the PacketFence API, so the admin token never reaches the
  // remote and the file never renders in the admin origin.
  const fetch = (recording, action) => {
    busy.value = recording.name
    busyAction.value = action
    return api.terminalRecording(props.id, recording.name).catch(err => {
      $store.dispatch('notification/danger', { message: errorMessage(err, i18n.t('Unable to fetch the terminal recording from the remote connector.')) })
      throw err
    }).finally(() => {
      busy.value = null
      busyAction.value = null
    })
  }

  // stopPlayer tears the player down; disposePlayer also forgets which
  // recording was playing (modal closed).
  const stopPlayer = () => {
    if (player) {
      try {
        player.dispose()
      } catch (e) {
        // the player is gone with the modal
      }
      player = null
    }
  }
  const disposePlayer = () => {
    stopPlayer()
    playing.value = null
  }

  const play = recording => {
    fetch(recording, 'play').then(data => {
      playing.value = recording
      playerTitle.value = `${i18n.t('Terminal session')} · ${formatDate(recording.started_at)}${recording.admin_user ? ` · ${recording.admin_user}` : ''}`
      showPlayer.value = true
      // The modal body exists once it is shown.
      nextTick(() => {
        stopPlayer()
        if (!playerRef.value)
          return
        player = AsciinemaPlayer.create({ data }, playerRef.value, {
          autoPlay: true,
          fit: 'width',
          idleTimeLimit: 2,
          terminalFontSize: 'small',
          theme: 'asciinema'
        })
      })
    }).catch(() => {})
  }
  const download = recording => {
    fetch(recording, 'download').then(data => {
      useDownload(recording.name, data, 'application/x-asciicast')
    }).catch(() => {})
  }

  const formatDate = value => {
    if (!value)
      return '-'
    const date = new Date(value)
    return isNaN(date.getTime()) ? '-' : date.toLocaleString()
  }

  const formatDuration = seconds => {
    if (!seconds && seconds !== 0)
      return '-'
    const total = Math.round(seconds)
    const h = Math.floor(total / 3600)
    const m = Math.floor((total % 3600) / 60)
    const s = total % 60
    return h ? `${h}h ${m}m ${s}s` : (m ? `${m}m ${s}s` : `${s}s`)
  }

  const formatBytes = bytes => {
    if (!bytes && bytes !== 0)
      return '-'
    const units = ['B', 'KB', 'MB', 'GB']
    let value = bytes
    let unit = 0
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024
      unit++
    }
    return `${value.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`
  }

  onMounted(refresh)
  onBeforeUnmount(disposePlayer)

  return {
    recordings,
    error,
    isLoading,
    busy,
    busyAction,
    showPlayer,
    playerTitle,
    playing,
    playerRef,
    refresh,
    play,
    download,
    disposePlayer,
    formatDate,
    formatDuration,
    formatBytes
  }
}

// @vue/component
export default {
  name: 'the-terminal-recordings',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.pf-asciinema {
  min-height: 24rem;
  .ap-wrapper {
    width: 100%;
  }
}
</style>
