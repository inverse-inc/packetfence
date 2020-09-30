export const pfSchedules = [
  '@every 1s',
  '@every 2s',
  '@every 3s',
  '@every 5s',
  '@every 10s',
  '@every 15s',
  '@every 30s',
  '@every 45s',

  '@every 1m',
  '@every 2m',
  '@every 3m',
  '@every 5m',
  '@every 10m',
  '@every 15m',
  '@every 30m',
  '@every 45m',

  '@every 1h',
  '@every 2h',
  '@every 3h',
  '@every 4h',
  '@every 6h',
  '@every 8h',
  '@every 12h',
  '@every 16h',
  '@every 20h',
  '@every 24h',
]

export const pfSchedulesList = pfSchedules.map(schedule => { return { text: schedule, value: schedule } })
