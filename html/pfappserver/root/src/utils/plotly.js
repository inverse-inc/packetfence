// https://plot.ly/javascript/reference/
// https://plot.ly/javascript/plotlyjs-function-reference/
import Plotly from 'plotly.js-dist-min'

import fr from 'plotly.js-locales/fr'
Plotly.register(fr)

export default Plotly

export const config = {
  displayModeBar: true,
  scrollZoom: true,
  displaylogo: false,
  showLink: false,
  showEditInChartStudio: true,
  plotlyServerURL: "https://chart-studio.plotly.com"
}
