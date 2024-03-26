const { SCOPE_UPDATE } = require('../config');
const maintenanceTasks = require('../../../cypress/fixtures/runtime/maintenanceTasks.json');
const collection_url = '/configuration/maintenance_tasks';
const resource_url = id => `/configuration/maintenance_task/${id}`;

module.exports = {
  id: 'maintenaceTasks',
  description: 'Maintenance Tasks',
  tests: maintenanceTasks.map(id => {
    const fixture = require(`../../../cypress/fixtures/runtime/maintenanceTask-${id}.json`)
    return {
      description: `Maintenance Task (${id}) - Update Existing`,
      scope: SCOPE_UPDATE,
      fixture: `/runtime/maintenanceTask-${id}.json`,
      url: resource_url,
      interceptors: [
        {
          method: '+(PATCH|PUT)',
          url: '/api/**/config/maintenance_task/**',
          expectRequest: (request, fixture) => {
            Object.keys(fixture).forEach(key => {
              expect(request.body).to.have.property(key)
              expect(request.body[key]).to.deep.equal(fixture[key], key)
            })
          },
          expectResponse: (response, fixture) => {
            expect(response.statusCode).to.equal(200)
          }
        }
      ]
    }
  })
};