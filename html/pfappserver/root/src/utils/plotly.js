// https://plot.ly/javascript/reference/
// https://plot.ly/javascript/plotlyjs-function-reference/
import Plotly from 'plotly.js/lib/core'
import PlotlyBar from 'plotly.js/lib/bar'
import PlotlyPie from 'plotly.js/lib/pie'
import PlotlyScatter from 'plotly.js/lib/scatter'
import PlotlyParcats from 'plotly.js/lib/parcats'

Plotly.register([PlotlyBar, PlotlyPie, PlotlyScatter, PlotlyParcats])

import fr from 'plotly.js-locales/fr'
Plotly.register(fr)

export default Plotly

export const config = {
  displaylogo: false,
  displayModeBar: true,
  responsive: true,
  scrollZoom: true,
  showEditInChartStudio: true,
  showLink: false,
  plotlyServerURL: 'https://chart-studio.plotly.com',
}
