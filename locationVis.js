var LocationVis = function(opts) {
  
  this.element     = opts.element; // DOM element to append to
  this.data        = opts.data.filter(d => d.locId != "OP");
  this.xyData      = opts.xyData
  this.focusLoc    = opts.focusLoc;
  this.timeRange   = opts.timeRange;
  this.margin      = opts.margin;
  this.height      = opts.height - this.margin.top - this.margin.bottom;
  this.width       = opts.width - this.margin.left - this.margin.right;
  this.onClickLoc  = function(d) {
    opts.onClickLoc(d);
    // Todo: ugly hack. Do better
    setTimeout(function() {
      d3.selectAll(".flowLine").classed("highlight", true)
      d3.selectAll(".locCircleBg").classed("highlight", true)
    }, 700)
  }
  
  this.draw();
}


LocationVis.prototype.draw = function() {
  
  var svg = this.element.append('svg')
    .attr('width', this.width + this.margin.left + this.margin.right)
    .attr('height', this.height + this.margin.top + this.margin.bottom);
  
  this.plot = svg.append('g')
      .attr("transform", "translate(" + this.margin.left + "," + this.margin.top + ")");

  this.heatmap = this.plot.append("g");
  this.mapCircles = this.plot.append("g");

  this.createScales();

  this.heatmap
  .append("rect")
  .attr("width", this.width) 
  .attr("height", this.height) 
  .attr("fill", this.heatmapScale(0)) 

  this.addHeatmap();
  this.addMapCircles();

  this.tooltip = this.plot.append("g")
  .style("display", "none");

  this.tooltip.append("rect")
  .attr("width", 130)
  .attr("height", 25)
  .attr("transform", "translate(-65,0)")
  .attr("class", "tooltip")
  .style("fill", "white")
  .style("opacity", 0.9);
  
  this.tooltip.append("text")
  .attr("id", "line1")
  .attr("transform", "translate(0,15)")
  .attr("class", "tooltiptext")
  .style("text-anchor", "middle")
  .style("fill", "black")
  .style("font-size", 11)
}


LocationVis.prototype.update = function(xyData, focusLoc, timeRange) {
  this.xyData = xyData;

  this.heatmapScale.domain([0, d3.max(this.xyData, d => d.n)]);

  this.focusLoc = focusLoc;
  this.timeRange = timeRange;
  this.addMapCircles();
  this.addHeatmap();
}


LocationVis.prototype.createScales = function() {

  this.xScale = d3.scaleLinear()
    .domain([0, d3.max(this.data, d => d.x)])
    .range([0, Math.min(this.width, this.height)]);

  this.yScale = d3.scaleLinear()
    .domain([0, d3.max(this.data, d => d.y)])
    .range([Math.min(this.width, this.height), 0]);

  this.heatmapScale = d3.scaleSequential(d3.interpolateMagma)
    .domain([0, d3.max(this.xyData, d => d.n)]);

  this.catScale = d3.scaleOrdinal()
    .domain(["Kiddie Rides", "Rides for Everyone", "Thrill Rides", "Shows & Entertainment", "Other"])
    .range(["#4daf4a", "#377eb8" , "#e41a1c", "#984ea3", "#555"].map(d => d3.hsl(d).brighter()))
}


LocationVis.prototype.addMapCircles = function() {

  // store 'this' for use inside callback functions
  var _this = this;

  var mapCircles = this.mapCircles.selectAll(".mapCircle")
    .data(this.data, d => d.locId)

  mapCircles
    .exit()
    .remove();

  mapCircles
    .enter()
      .append("circle")
      .attr("r", 6)
      .attr("cx", d => _this.xScale(d.x))
      .attr("cy", d => _this.yScale(d.y))
      .attr("class", "mapCircle")
      .on("click", d => _this.onClickLoc(d.locId))
      .on("mouseenter", hoverCircleIn)
      .on("mouseout", hoverCircleOut)
      .on("mousemove", hoverCircleMove)
    .merge(mapCircles)
      .attr("fill", d => _this.catScale(d.category))
      .classed("focus", d => d.locId == _this.focusLoc ? true : false);

  this.mapCircles.selectAll(".focus")
    .moveToFront()
    
  function hoverCircleIn() {
    _this.tooltip.style("display", null)
  }
    
  function hoverCircleOut() {
    _this.tooltip.style("display", "none")
  }
  
  function hoverCircleMove(d) {
    var xPos = d3.mouse(this)[0];

    if(xPos > _this.width - 65) {
      xPos = xPos - 65
     } else if (xPos < 65) {
       xPos = xPos + 65
     }
    var yPos = d3.mouse(this)[1] + 20;

    _this.tooltip.attr("transform", "translate(" + xPos + "," + yPos + ")");
    _this.tooltip.select("#line1").text(d.label);
  }
}


LocationVis.prototype.addHeatmap = function() {

  // store 'this' for use inside callback functions
  var _this = this;

  var tiles = this.heatmap.selectAll(".heatmapTile")
    .data(this.xyData)

  tiles
    .exit()
    .remove();

  tiles
    .enter()
      .append("rect")
      .attr("width", 3)
      .attr("height", 3)
      .attr("x", d => _this.xScale(+d.x))
      .attr("y", d => _this.yScale(+d.y))
      .attr("class", "heatmapTile")
    .merge(tiles)
      .transition()
      .duration(100)
      .attr("fill", d => _this.heatmapScale(d.n));
}