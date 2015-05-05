var graphs = {
    charts: {},
    resize_timeout: null
};

function graphLineData(holder, labels, series) {
    var div = $('#'+holder),
    width = div.width(),
    height = 250,
    margin = 50;

    if (width == null) return;
    if (labels.length < 2) return;

    div.css({ height: (2*height)+'px' }); // leave plenty of space for the legend

    var count = 0,
    xstep = (width <= 575)? 4:8,
    ystep = 8,
    axisxstep = labels.length - 1,
    axisystep = 8,
    labelxstep = Math.round(labels.length/xstep),
    max = 0,
    valuesx = [],
    valuesy = [],
    legend = [],
    sums = [],
    i = 0,
    j = 0;

    // Extract legend and values
    for (var name in series) {
        legend.push(name);
        valuesx[i] = [];
        valuesy[i] = [];
        sums[name] = 0;
        if (series[name].length > count) count = series[name].length;
        for (j = 0; j < labels.length; j++) {
            valuesx[i][j] = j;
            valuesy[i][j] = series[name][j];
            sums[name] += series[name][j];
            if (valuesy[i][j] > max) max = valuesy[i][j];
        }
        i++;
    }

    // Compute the y-axis step based on the maximum y-value
    if (max < ystep)
        axisystep = max;

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
        box.push(r.text(x + 20, h, legend[i].toLowerCase())
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
                                symbol: (count > 90)? "" : "circle",
                                smooth: false,
                                //dash: "-",
                                shade: true,
                                colors: colors
                            }
                           );
    chart.hoverColumn(function () {
        // Show tag when mouse over column
        this.tags = r.set();
        for (var i = 0, ii = this.y.length; i < ii; i++) {
            this.tags.push(
                //r.popup(this.x, this.y[i] - 5, this.values[i]).insertBefore(this)
                r.tag(this.x, this.y[i], this.values[i], 160, 7).insertBefore(this).attr(
                    [
                        { fill: '#fff' },
                        { fill: this.symbols[i]? this.symbols[i].attr("fill") : '#000' }
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

    // Draw horizontal gridlines
    for (i = 0; i < chart.axis[1].text.items.length; i++) {
        r.path(['M', 25, chart.axis[1].text.items[i].attrs.y, 'H', width - 35]).attr({
            stroke : '#EEE'
        }).toBack();
        var label = chart.axis[1].text.items[i];
        if (i > 0) {
            var j = parseInt(label.attr('text'));
            if (j == 0) {
                label.hide();
            }
        }
    }
    chart.axis[1].attr({stroke: '#FFF'});
    //chart.axis[1].translate.apply(chart.axis[1], [10, 0]);

    // Set x-axis labels
    for (var j = 0, last = 0; j < chart.axis[0].text.items.length; j++) {
        var label = chart.axis[0].text.items[j];
        var i = parseInt(label.attr('text'));
        var cur = i % labelxstep;
        if (cur == 0 || cur < last) {
            label.attr({'text': labels[i]});
        }
        else {
            label.attr({'text': ' '});
        }
        last = cur;
    }

    // Display counters
    var counters = legend.slice(0); // clone legend
    counters.sort(function(a, b) {
        return sums[b] - sums[a];
    });
    counters.splice(5);
    var w = (width-margin-5*(counters.length-1))/counters.length,
    grey = '60-#333-#666';
    grey = '#eee';
    x = margin/2, h += height;
    for (i = 0; i < counters.length; i++) {
        var clr = Raphael.color(colors[jQuery.inArray(counters[i], legend)]);
        var clrlt = 'hsb(' + (clr.h) + ', ' + (clr.s) + ', ' + (clr.v + .1) + ')';
        var clrltr = 'hsb(' + (clr.h) + ', ' + (clr.s) + ', ' + 0.9 + ')';
        var box = r.set();
        box.push(r.rect(x, h, w, 50, 5)
                 .attr({fill: "30-"+clr+"-"+clr+":70-"+clrlt, stroke: "none"}));
        r.text(x + w/2, h + 12, counters[i].toUpperCase())
            .attr({"font-size": "10px", "font-weight": "800", fill: clrltr});
        r.text(x + w/2, h + 32, sums[counters[i]])
            .attr({"font-size": "24px", "font-weight": "800", fill: '#fff'});
        x += box.getBBox().width + 5;
    }

    // Increase height of containing div and svg
    div.css({ height: (height+h)+'px' });
    var svg = div.children('svg');
    if (svg.length) svg.attr('height', (height+h));
}

function graphPieData(holder, labels, series) {
    var div = $('#'+holder),
    labels_formatted = [],
    values = series['values'].slice(0),
    width = div.width(),
    height = 250,
    ray = 90;

    for (var i = 0; i < labels.length; i++)
        labels_formatted[i] = labels[i] + " - %%.%%";

    div.css({height: height+'px' });

    var r = Raphael(holder),
    txtattr = { font: "12px 'Fontin Sans', Fontin-Sans, sans-serif" };

    var chart = r.piechart(parseInt(width*.75), parseInt(height*.4),
                           ray,
                           values,
                           {
                               maxSlices: 10,
                               legend: labels_formatted,
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
            var e = $('#'+this.label[1].attr("text").replace(/ - [0-9\.]+%$/, '').asCSSIdentifier());
            if (e) e.addClass('active');
        }
    }, function () {
        this.sector.animate({ transform: 's1 1 ' + this.cx + ' ' + this.cy }, 500, "bounce");
        
        if (this.label) {
            this.label[0].animate({ r: 5 }, 500, "bounce");
            this.label[1].attr({ "font-weight": 400 });
            var e = $('#'+this.label[1].attr("text").replace(/ - [0-9\.]+%$/, '').asCSSIdentifier());
            if (e) e.removeClass('active');
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
    chart.customLabel = function (labels) {
        labels = labels || [];
        this.labels = r.set();
        for (var i = 0; i < this.bars[0].length; i++) {
            x = this.bars[0][i].x;
            y = this.bars[0][i].y + this.bars[0][i].h + 10;
            r.text(x, y, labels[i]).attr(txtattr);
        }
        h += 10;
        return this;
    };
    chart.customLabel(labels);
    chart.hover(fin, fout);

    $('#'+holder).css({ height: (height+h)+'px' });
    var svg = $('#'+holder).children('svg');
    if (svg) svg.attr('height', (height+h));
}

function graphDotData(holder, ylabels, xlabels, series) {
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

function drawGraphs(id) {
    var _graphs = {};
    if (id)
        _graphs[id] = graphs.charts[id];
    else
        _graphs = graphs.charts;

    for (var name in _graphs) {
        var graph = _graphs[name];
        $('#'+name).empty();

        switch(graph['type']) {
        case 'pie':
            graphPieData(name, graph['labels'], graph['series']);
            break;
        case 'bar':
            graphBarData(name, graph['size'], graph['labels'], graph['series']);
            break;
        case 'dot':
            graphDotData(name, graph['ylabels'], graph['xlabels'], graph['series']);
            break;
        case 'stacked':
            graphBarData(name, graph['size'], graph['labels'], graph['series']);
            break;
        default:
            graphLineData(name, graph['labels'], graph['series']);
        }
    }
}

$(function() {
    $(window).on('resize', function(event) {
        // When resizing the window, rebuild the graphs after a delay of 100 miliseconds
      if (graphs.resize_timeout) window.clearTimeout(graphs.resize_timeout);
        graphs.resize_timeout = window.setTimeout(drawGraphs, 1000);
    });
});
