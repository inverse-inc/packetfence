var graphs = new Hash();
window.onload = function () {
    function graphLineData(holder, size, labels, series) {
        var width = (size == 'small')? 460:800,
        height = 250,
        margin = 50;

        if (labels.length < 2) return;

        $(holder).setStyle({ width: width+'px',
                             height: height+'px' });

        var maxdots = parseInt(width/20),
        increment = (labels.length > maxdots)? Math.round(labels.length/maxdots) : 1,
        axisxstep = ((size == 'small' || j < 8)?4:8),
        valuesx = [],
        valuesy = [],
        legend = [],
        i = 0,
        j = 0;
        for (var name in series) {
            legend.push(name);
            valuesx[i] = [];
            valuesy[i] = [];
            for (var jj = 0, j = 0; jj < labels.length; j++, jj += increment) {
                valuesx[i][j] = j;
                valuesy[i][j] = series[name][jj];
            }
            i++;
        }

        var r = Raphael(holder),
        txtattr = { font: "12px 'Fontin Sans', Fontin-Sans, sans-serif" };

        var chart = r.linechart(25, 25, // x, y
                                width-margin, height-margin-20, // width, height
                                valuesx,
                                valuesy,
                                {   // options
                                    nostroke: false,
                                    axis: "0 0 1 1",
                                    axisxstep: axisxstep,
                                    symbol: "circle",
                                    smooth: true,
                                    //dash: "-",
                                    shade: true
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
            chart.lines[i].animate({"stroke-width": 3}, 1000);
            chart.symbols[i].attr({stroke: "#fff"});
        }

        // Set x-axis labels
        chart.axis[0].text.items.each( function (label, index) {
            var i = parseInt(label.attr('text'));
            label.attr({'text': labels[i*increment]});
        });

        // Print legend
 	chart.legend = r.set();
 	var x = 15, h = 5;
 	for(i = 0; i < legend.length; ++i) {
 	    var clr = chart.lines[i].attr("stroke");
 	    chart.legend.push(r.set());
 	    chart.legend[i].push(r.circle(x + 5, h, 5)
 	                         .attr({fill: clr, stroke: "none"}));
 	    chart.legend[i].push(r.text(x + 20, h, legend[i])
 	                         .attr(txtattr)
 	                         .attr({fill: "#000", "text-anchor": "start"}));
 	    x += chart.legend[i].getBBox().width * 1.2;
 	};
        var bb = chart.legend.getBBox(),
        tr = [width - margin - bb.width, 0];

        chart.legend.translate.apply(chart.legend, tr);
        chart.push(chart.legend);
    }

    function graphPieData(holder, size, labels, series) {
        var width = 500,
        height = 250,
        ray = 90;

        $(holder).setStyle({ width: width+'px',
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
        var width = 500,
        height = 250,
        margin = 50;

        $(holder).setStyle({ width: width+'px',
                             height: height+'px' });

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

        fin = function () {
            this.flag = r.popup(this.bar.x, this.bar.y, this.bar.value || "0").insertBefore(this);
        },
        fout = function () {
            this.flag.remove();
        },
        txtattr = { font: "12px 'Fontin Sans', Fontin-Sans, sans-serif" };
                
        var chart = r.barchart(10, 10,
                               width, height,
                               values,
                               {
                                   stacked: true,
                                   type: "soft",
                               }
                              ).hover(fin, fout);

        // Print legend
 	chart.legend = r.set();
 	var x = 15, h = 5;
 	for(i = 0; i < legend.length; ++i) {
 	    var clr = chart.bars[i][0].attr("fill");
 	    chart.legend.push(r.set());
 	    chart.legend[i].push(r.circle(x + 5, h, 5)
 	                         .attr({fill: clr, stroke: "none"}));
 	    chart.legend[i].push(r.text(x + 20, h, legend[i])
 	                         .attr(txtattr)
 	                         .attr({fill: "#000", "text-anchor": "start"}));
 	    x += chart.legend[i].getBBox().width * 1.2;
 	};
        var bb = chart.legend.getBBox(),
        tr = [width - margin - bb.width, 0];

        chart.legend.translate.apply(chart.legend, tr);
        chart.push(chart.legend);
    }

    /* Draw graphs */
    graphs.keys().each(function(name) {
        var graph = graphs.get(name);

        switch(graph['type']) {
        case 'pie':
            graphPieData(name, graph['size'], graph['labels'], graph['series']);
            break;
        case 'bar':
            graphBarData(name, graph['size'], graph['labels'], graph['series']);
            break;
        case 'stacked':
            graphBarData(name, graph['size'], graph['labels'], graph['series']);
            break;
        default:
            graphLineData(name, graph['size'], graph['labels'], graph['series']);
        }

        var div = $(name);
  
        var header = new Element('div', {"class": "chart"});
        header.setStyle({ width: div.getStyle('width') });

        var e = new Element('h2', {"class": "chart"});
        e.update(graph['title']);
        header.appendChild(e);

        var s = new Element('span', {"class": "chart"});
        s.update(graph['subtitle']);
        header.appendChild(s);

        div.parentNode.insertBefore(header, div);
    });
};