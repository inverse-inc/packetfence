var graphs = {};

function graphLineData(holder, size, labels, series) {
    var width = (size == 'small')? 460:800,
    height = 250,
    margin = 50;

    if (labels.length < 2) return;

    $('#'+holder).css({ width: width+'px',
                        height: (2*height)+'px' }); // leave plenty of space for the legend

    var maxdots = parseInt(width/20),
    increment = (labels.length > maxdots)? Math.round(labels.length/maxdots) : 1,
    xstep = (size == 'small')? 4:8,
    ystep = 8,
    axisxstep =  (labels.length > xstep)? xstep : labels.length - 1,
    axisystep = 0,
    max = 0,
    xoverflow = (labels.length > xstep)? (labels.length % axisxstep) - 1 : 0,
    valuesx = [],
    valuesy = [],
    legend = [],
    i = 0,
    j = 0;

    // Drop some values if not dividable by the x-steps
    if (xoverflow > 0)
        labels.splice(0, xoverflow);

    for (var name in series) {
        legend.push(name);
        valuesx[i] = [];
        valuesy[i] = [];
        if (xoverflow > 0)
            series[name].splice(0, xoverflow);
        for (var jj = 0, j = 0; jj < labels.length; j++, jj += increment) {
            valuesx[i][j] = j;
            valuesy[i][j] = series[name][jj];
            if (valuesy[i][j] > max) max = valuesy[i][j];
        }
        i++;
    }

    // Compute the y-axis step based on the maximum y-value
    if (max % 2 > 0)
        max++;
    if (max < ystep)
        axisystep = max;
    else {
        var k = ystep;
        while (max % k > 0 && k > 0)
            k--;
        axisystep = k;
    }

    var r = Raphael(holder),
    txtattr = { font: "12px 'Fontin Sans', Fontin-Sans, sans-serif" };

    // Print legend at top
    var colors = Raphael.g.colors,
    white = Raphael.color("white");
    // Generate more colors if necessary
    for (i = colors.length, j = 0; i < legend.length; i++, j++) {
        colors[i] = Raphael.color(colors[j]);
        colors[i] = 'hsb(' + (1 - colors[i].h) + ', ' + colors[i].s + ', ' + colors[i].v + ')';
    }
    var x = 15, h = 5, j = 0, lines = [];
    for (i = 0, lines[j] = r.set(); i < legend.length; ++i) {
        var clr = colors[i];
        var box = r.set();
        box.push(r.rect(x-6, h-1, 22, 2)
                 .attr({fill: clr, stroke: "none"}));
        box.push(r.circle(x + 5, h, 5)
                 .attr({fill: white, stroke: white}));
        box.push(r.circle(x + 5, h, 4)
                 .attr({fill: clr, stroke: "none"}));
        box.push(r.text(x + 20, h, legend[i])
                 .attr(txtattr)
                 .attr({fill: "#000", "text-anchor": "start"}));
        x += box.getBBox().width + 15;
        
        if (x > (width - margin) && lines[j].length > 1) {
            // Create a new line
            x = 15, h += box.getBBox().height * 1.2;
            box.remove();
            var bb = lines[j].getBBox(),
            tr = [width - margin - bb.width, 0];
            lines[j].translate.apply(lines[j], tr);
            j++, i--;
            lines[j] = r.set();
        }
        else {
            lines[j].push(box);
        }
    };
    var bb = lines[j].getBBox(),
    tr = [width - margin - bb.width, 0];
    lines[j].translate.apply(lines[j], tr);

    // Create graph
    var chart = r.linechart(25, 20 + h, // x, y
                            width-margin, height-margin-20, // width, height
                            valuesx,
                            valuesy,
                            {   // options
                                nostroke: false,
                                axis: "0 0 1 1",
                                axisxstep: axisxstep,
                                axisystep: axisystep,
                                ydim: { from: 0, to: max, power: 1 },
                                symbol: "circle",
                                smooth: false,
                                //dash: "-",
                                shade: false,
                                colors: colors
                            }
                           );
    chart.hoverColumn(function () {
        // Show tag when mouse over column
        this.tags = r.set();
        for (var i = 0, ii = this.y.length; i < ii; i++) {
            this.tags.push(
                r.tag(this.x, this.y[i], this.values[i], 160, 10).insertBefore(this).attr(
                    [
                        { fill: "#fff" },
                        { fill: this.symbols[i].attr("fill") }
                    ]
                )
            );
        }
    }, function () {
        this.tags && this.tags.remove();
    });

    // Line width
    chart.symbols.attr({ r: 4 });

    for (i = 0; i < chart.lines.length; i++) {
        //chart.lines[i].animate({"stroke-width": 3}, 2000);
        chart.lines[i].attr({"stroke-width": 3});
        chart.symbols[i].attr({stroke: "#fff"});
    }

    // Set x-axis labels
    for (var j = 0; j < chart.axis[0].text.items.length; j++) {
        var label = chart.axis[0].text.items[j];
        var i = parseInt(label.attr('text'));
        label.attr({'text': labels[i*increment]});
    }

    $('#'+holder).css({ height: (height+h)+'px' });
    var svg = $('#'+holder).children('svg');
    if (svg.length) svg.attr('height', (height+h));
}

 function graphPieData(holder, size, labels, series) {
    var width = 600,
    height = 250,
    ray = 90;

    for (var i = 0; i < labels.length; i++)
        labels[i] += " - %%.%%";

    $('#'+holder).css({ width: width+'px',
                        height: height+'px' });

    var r = Raphael(holder),
    txtattr = { font: "12px 'Fontin Sans', Fontin-Sans, sans-serif" };

    var chart = r.piechart(parseInt(width*.75), parseInt(height*.4),
                           ray,
                           series['values'],
                           {
                               legend: labels,
                               legendpos: "west"
                           }
                          );

    chart.hover(function () {
        this.sector.stop();
        this.sector.scale(1.1, 1.1, this.cx, this.cy);
        
        if (this.label) {
            this.label[0].stop();
            this.label[0].attr({ r: 7.5 });
            this.label[1].attr({ "font-weight": 800 });
        }
    }, function () {
        this.sector.animate({ transform: 's1 1 ' + this.cx + ' ' + this.cy }, 500, "bounce");
        
        if (this.label) {
            this.label[0].animate({ r: 5 }, 500, "bounce");
            this.label[1].attr({ "font-weight": 400 });
        }
    });
}

function graphBarData(holder, size, labels, series) {
    var width = 800,
    height = 250,
    margin = 50;

    $('#'+holder).css({ width: width+'px',
                        height: (2*height)+'px' }); // leave plenty of space for the legend

    var values = [];
    var legend = [];
    var i = 0;
    for (var name in series) {
        legend.push(name);
        values[i] = [];
        for (var j = 0; j < labels.length; j++) {
            values[i][j] = series[name][j];
        }
        i++;
    }

    var r = Raphael(holder),
    txtattr = { font: "12px 'Fontin Sans', Fontin-Sans, sans-serif" };

    // Print legend at top
    var colors = Raphael.g.colors;
    var x = 15, h = 5, j = 0, lines = [];
    for(i = 0, lines[j] = r.set(); i < legend.length; ++i) {
 	var clr = colors[i];
 	var box = r.set();
        box.push(r.circle(x + 5, h, 5)
 	         .attr({fill: clr, stroke: "none"}));
 	box.push(r.text(x + 20, h, legend[i])
 	         .attr(txtattr)
 	         .attr({fill: "#000", "text-anchor": "start"}));
 	x += box.getBBox().width + 15;

        if (x > (width - margin) && lines[j].length > 1) {
            // Create a new line
            x = 15, h += box.getBBox().height * 1.2;
            box.remove();
            var bb = lines[j].getBBox(),
            tr = [width - margin - bb.width, 0];
            lines[j].translate.apply(lines[j], tr);
            j++, i--;
            lines[j] = r.set();
        }
        else {
            lines[j].push(box);
        }
    };
    var bb = lines[j].getBBox(),
    tr = [width - margin - bb.width, 0];
    lines[j].translate.apply(lines[j], tr);

    var fin = function () {
        this.flag = r.popup(this.bar.x, this.bar.y, this.bar.value || "0").insertBefore(this);
    },
    fout = function () {
        this.flag.remove();
    };
    
    // Create graph
    var chart = r.barchart(10, 10 + h,
                           width, height,
                           values,
                           {
                               stacked: true,
                               type: "soft"
                           }
                          );
    chart.hover(fin, fout);

    $('#'+holder).css({ height: (height+h)+'px' });
    var svg = $('#'+holder).children('svg');
    if (svg) svg.attr('height', (height+h));
}

function graphDotData(holder, size, ylabels, xlabels, series) {
    var width = xlabels.length * 32,
    height = ylabels.length * 50;

    var values = [];
    var xs = [];
    var ys = [];

     $('#'+holder).css({ width: width+'px',
                         height: (height + 50)+'px' });

    for (var j = 0; j < ylabels.length; j++) {
        var y = ylabels[j];
        for (var i = 0; i < series[y].length; i++) {
            xs.push(i);
            ys.push(j+1);
            values.push(series[y][i]);
        }
    }

    var r = Raphael(holder),
    txtattr = { font: "12px 'Fontin Sans', Fontin-Sans, sans-serif" };
    var chart = r.dotchart(10, 0,
                           width, height,
                           xs, ys, values,
                           {
                               symbol: "o",
                               max: 12,
                               heat: false,
                               axis: "0 0 1 1",
                               axisxstep: xlabels.length - 1, //(xlabels.length > 1)?2:1,
                               axisystep: ylabels.length - 1,
                               axisxtype: " ",
                               axisytype: " ",
                               axisxlabels: xlabels,
                               axisylabels: ylabels
                           }
                          );

    // Customize x-axis
    for (var j = 0; j < chart.axis[0][1].items.length; j++) {
        var label = chart.axis[0][1].items[j];
        // Rotate and translate label
        label.transform("R30").translate(30, 0);
        // Add vertical line above label
        var lx = label.getBBox().x;
        r.rect(lx+1, 15, 1, 70).attr({fill: Raphael.color("#ccc"), stroke: "none"}).toBack();
    }

    // Set the graph height a little smaller than the container
     var svg = $('#'+holder).children('svg');
     if (svg) svg.attr('height', (height+45));
}

function drawGraphs() {
    for (var name in graphs) {
        var graph = graphs[name];

        switch(graph['type']) {
        case 'pie':
            graphPieData(name, graph['size'], graph['labels'], graph['series']);
            break;
        case 'bar':
            graphBarData(name, graph['size'], graph['labels'], graph['series']);
            break;
        case 'dot':
            graphDotData(name, graph['size'], graph['ylabels'], graph['xlabels'], graph['series']);
            break;
        case 'stacked':
            graphBarData(name, graph['size'], graph['labels'], graph['series']);
            break;
        default:
            graphLineData(name, graph['size'], graph['labels'], graph['series']);
        }
    }
}
