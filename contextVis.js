var ContextVis = function(opts) {
  
  this.element    = opts.element; // DOM element to append to
  this.dataTotal  = opts.dataTotal;
  this.dataFocus  = opts.dataFocus;
  this.margin     = opts.margin;
  this.height     = opts.height - this.margin.top - this.margin.bottom;
  this.width      = opts.width - this.margin.left - this.margin.right;
  this.onBrush    = function(d) {
    opts.onBrush(d);
    // Todo: ugly hack. Do better
    setTimeout(function() {
      d3.selectAll(".flowLine").classed("highlight", true)
      d3.selectAll(".locCircleBg").classed("highlight", true)
    }, 100)
  }

  this.draw();
}


ContextVis.prototype.draw = function() {
  
  var svg = this.element.append('svg')
    .attr('width', this.width + this.margin.left + this.margin.right)
    .attr('height', this.height + this.margin.top + this.margin.bottom);
  
  this.plot = svg.append('g')
      .attr("transform", "translate(" + this.margin.left + "," + this.margin.top + ")");

  this.createScales();
  this.addTotal();
  this.addFocus();
  this.addAxes();
}

ContextVis.prototype.createScales = function() {

  this.xScale = d3.scaleLinear()
    .domain([d3.min(this.dataTotal, d => d.timeBin), d3.max(this.dataTotal, d => d.timeBin)])
    .range([0, this.width]);

  this.yScale = d3.scaleLinear()
    .domain([0, d3.max(this.dataTotal, d => d.totalVisitors)])
    .range([this.height, 0]);

  this.yScaleFocus = d3.scaleLinear()
    .domain([0, d3.max(this.dataFocus, d => d.stat1)])
    .range([this.height, 0]);

  this.lineTotal = d3.line()
    .curve(d3.curveBasis)
    .x(d => this.xScale(d.timeBin))
    .y(d => this.yScale(d.totalVisitors))

  this.lineFocus = d3.line()
    .curve(d3.curveBasis)
    .x(d => this.xScale(d.time))
    .y(d => this.yScaleFocus(d.stat1))
}


ContextVis.prototype.addAxes = function() {

  var _this = this;

  // axes
  var xAxis  = d3.axisBottom(this.xScale)
    .tickFormat(d => _this.dataTotal.find(e => e.timeBin == d).startShort);

  var yAxis  = d3.axisLeft(this.yScale).ticks(4);
  var yAxis2 = d3.axisRight(this.yScaleFocus).ticks(4);

  this.plot.append("g")
    .attr("class", "xaxis")
    .attr("transform", "translate(0," + this.height + ")")
    .call(xAxis); 

  this.plot.append("g")
    .attr("class", "yaxis")
    .call(yAxis); 

  this.plot.append("g")
  .attr("class", "yaxisFocus")
  .attr("transform", "translate(" + this.width + ",0)")
  .call(yAxis2)
  
  // brush
  var brush = d3.brushX()
    .extent([[0, 0], [this.width, this.height]])
    .on("brush", brushing)
    .on("end", brushended);

    function brushing() { 
      if (!d3.event.sourceEvent) return; // Only transition after input.
      if (!d3.event.selection) return; // Ignore empty selections.
  
      var d0 = d3.event.selection.map(_this.xScale.invert);
      var d1 = d0.map(d => Math.round(d));
  
      // If empty when rounded, use floor & ceil instead.
      if (d1[0] >= d1[1]) {
        d1[0] = Math.floor(d0[0]);
        d1[1] = Math.ceil(d0[0]);
      }
  
      _this.onBrush(d1)
    }

  function brushended() {
    if (!d3.event.sourceEvent) return; // Only transition after input.
    if (!d3.event.selection) return _this.onBrush(_this.xScale.domain()) ;

    var d0 = d3.event.selection.map(_this.xScale.invert);
    var d1 = d0.map(d => Math.round(d));

    // If empty when rounded, use floor & ceil instead.
    if (d1[0] >= d1[1]) {
      d1[0] = Math.floor(d0[0]);
      d1[1] = Math.ceil(d0[0]);
    }
  
    // snap brush to rounded location
    d3.select(this)
      .transition()
      .call(d3.event.target.move, d1.map(_this.xScale))

    _this.onBrush(d1)
  }


  this.plot.append("g")
    .attr("class", "brush")
    .call(brush)
}


ContextVis.prototype.addTotal = function() {

  // store 'this' for use inside callback functions
  var _this = this;

  this.plot.append("path")
    .datum(this.dataTotal)   
    .attr("class", "contextTotal")
    .attr("d", this.lineTotal)
}


ContextVis.prototype.addFocus = function() {

  var _this = this;

  this.plot
    .append("path")
    .datum(this.dataFocus)   
    .attr("class", "contextFocus")
    .attr("d", this.lineFocus)
}


ContextVis.prototype.update = function(dataFocus) {

  this.dataFocus = dataFocus;

  this.yScaleFocus.domain([0, d3.max(this.dataFocus, d => d.stat1)])

  this.plot.selectAll(".contextFocus")   // change the line
  .datum(this.dataFocus)
  .transition()
  .duration(500)
  .attr("d", this.lineFocus);
}