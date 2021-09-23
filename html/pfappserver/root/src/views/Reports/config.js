// delimiter that separates id's into structured sidebar categories
export const delimiter = '::'

export const colorsFull = ['#ffff00', '#1ce6ff', '#ff34ff', '#ff4a46', '#008941', '#006fa6', '#a30059', '#ffdbe5', '#7a4900', '#0000a6', '#63ffac', '#b79762', '#004d43', '#8fb0ff', '#997d87', '#5a0007', '#809693', '#feffe6', '#1b4400', '#4fc601', '#3b5dff', '#4a3b53', '#ff2f80', '#61615a', '#ba0900', '#6b7900', '#00c2a0', '#ffaa92', '#ff90c9', '#b903aa', '#d16100', '#ddefff', '#000035', '#7b4f4b', '#a1c299', '#300018', '#0aa6d8', '#013349', '#00846f', '#372101', '#ffb500', '#c2ffed', '#a079bf', '#cc0744', '#c0b9b2', '#c2ff99', '#001e09', '#00489c', '#6f0062', '#0cbd66', '#eec3ff', '#456d75', '#b77b68', '#7a87a1', '#788d66', '#885578', '#fad09f', '#ff8a9a', '#d157a0', '#bec459', '#456648', '#0086ed', '#886f4c', '#34362d', '#b4a8bd', '#00a6aa', '#452c2c', '#636375', '#a3c8c9', '#ff913f', '#938a81', '#575329', '#00fecf', '#b05b6f', '#8cd0ff', '#3b9700', '#04f757', '#c8a1a1', '#1e6e00', '#7900d7', '#a77500', '#6367a9', '#a05837', '#6b002c', '#772600', '#d790ff', '#9b9700', '#549e79', '#fff69f', '#201625', '#72418f', '#bc23ff', '#99adc0', '#3a2465', '#922329', '#5b4534', '#fde8dc', '#404e55', '#0089a3', '#cb7e98', '#a4e804', '#324e72', '#6a3a4c', '#83ab58', '#001c1e', '#d1f7ce', '#004b28', '#c8d0f6', '#a3a489', '#806c66', '#222800', '#bf5650', '#e83000', '#66796d', '#da007c', '#ff1a59', '#8adbb4', '#1e0200', '#5b4e51', '#c895c5', '#320033', '#ff6832', '#66e1d3', '#cfcdac', '#d0ac94', '#7ed379', '#012c58', '#7a7bff', '#d68e01', '#353339', '#78afa1', '#feb2c6', '#75797c', '#837393', '#943a4d', '#b5f4ff', '#d2dcd5', '#9556bd', '#6a714a', '#001325', '#02525f', '#0aa3f7', '#e98176', '#dbd5dd', '#5ebcd1', '#3d4f44', '#7e6405', '#02684e', '#962b75', '#8d8546', '#9695c5', '#e773ce', '#d86a78', '#3e89be', '#ca834e', '#518a87', '#5b113c', '#55813b', '#e704c4', '#00005f', '#a97399', '#4b8160', '#59738a', '#ff5da7', '#f7c9bf', '#643127', '#513a01', '#6b94aa', '#51a058', '#a45b02', '#1d1702', '#e20027', '#e7ab63', '#4c6001', '#9c6966', '#64547b', '#97979e', '#006a66', '#391406', '#f4d749', '#0045d2', '#006c31', '#ddb6d0', '#7c6571', '#9fb2a4', '#00d891', '#15a08a', '#bc65e9', '#fffffe', '#c6dc99', '#203b3c', '#671190', '#6b3a64', '#f5e1ff', '#ffa0f2', '#ccaa35', '#374527', '#8bb400', '#797868', '#c6005a', '#3b000a', '#c86240', '#29607c', '#402334', '#7d5a44', '#ccb87c', '#b88183', '#aa5199', '#b5d6c3', '#a38469', '#9f94f0', '#a74571', '#b894a6', '#71bb8c', '#00b433', '#789ec9', '#6d80ba', '#953f00', '#5eff03', '#e4fffc', '#1be177', '#bcb1e5', '#76912f', '#003109', '#0060cd', '#d20096', '#895563', '#29201d', '#5b3213', '#a76f42', '#89412e', '#1a3a2a', '#494b5a', '#a88c85', '#f4abaa', '#a3f3ab', '#00c6c8', '#ea8b66', '#958a9f', '#bdc9d2', '#9fa064', '#be4700', '#658188', '#83a485', '#453c23', '#47675d', '#3a3f00', '#061203', '#dffb71', '#868e7e', '#98d058', '#6c8f7d', '#d7bfc2', '#3c3e6e', '#d83d66', '#000000']

export const colorsNull = ['#eeeeee']

export const layout = {
  pie: {
    autosize: true,
    hoverdistance: 100,
    hovermode: 'closest',
    spikedistance: 100,
    legend: {
      bgcolor: '#eee',
      bordercolor: '#eee',
      borderwidth: 10,
      orientation: 'v',
      xanchor: 'center',
      x: 1,
      y: 0.5
    },
    margin: {
      l: 25,
      r: 25,
      b: 50,
      t: 50,
      pad: 20,
      autoexpand: true
    }
  }
}

export const options = {
  pie: {
    type: 'pie',
    domain: {
      x: [0, 1],
      y: [0, 1]
    },
    hoverinfo: 'label+percent',
    hole: 0.25,
    marker: {
      line: {
        width: 0.5
      }
    },
    outsidetextfont: {
      family: '"Open Sans", verdana, arial, sans-serif',
      size: 12,
      color: '#444'
    },
    pull: 0,
    sort: true,
    textinfo: 'label',
    textfont: {
      family: '"Open Sans", verdana, arial, sans-serif',
      size: 12,
      color: '#444'
    },
    textposition: 'outside'
  }
}