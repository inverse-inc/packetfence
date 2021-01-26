import apiCall from '@/utils/api'

export default {
  maintenanceTasks: params => {
    return apiCall.get('config/maintenance_tasks', { params }).then(response => {
      return response.data
    })
  },
  maintenanceTasksOptions: () => {
    return apiCall.options('config/maintenance_tasks').then(response => {
      return response.data
    })
  },
  maintenanceTask: id => {
    return apiCall.get(['config', 'maintenance_task', id]).then(response => {
      return response.data.item
    })
  },
  maintenanceTaskOptions: id => {
    return apiCall.options(['config', 'maintenance_task', id]).then(response => {
      return response.data
    })
  },
  createMaintenanceTask: data => {
    return apiCall.post('config/maintenance_tasks', data).then(response => {
      return response.data
    })
  },
  updateMaintenanceTask: data => {
    return apiCall.patch(['config', 'maintenance_task', data.id], data).then(response => {
      return response.data
    })
  },
  deleteMaintenanceTask: id => {
    return apiCall.delete(['config', 'maintenance_task', id])
  }
}
