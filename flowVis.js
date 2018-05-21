var FlowVis = function(opts) {
    
  this.element   = opts.element; // DOM element to append to
  this.data      = opts.data;
  this.focusLoc  = opts.focusLoc; // "OP"
  this.timeRange = opts.timeRange;
  this.margin    = opts.margin;
  this.height    = opts.height - this.margin.top - this.margin.bottom;
  this.width     = opts.width - this.margin.left - this.margin.right;
  this.onRefocus = opts.onRefocus; // callback function

  this.barsExpanded = false;

  this.locs        = this.data.locs;
  this.visitorFlow = this.data.visitorFlow;
  this.timeSlots   = this.data.timeSlots;

  this.barHeightClp = 30;
  this.barHeightExp = 80,
  this.locCircleR   = 15;
  this.circleOffset = 100;

  
  this.draw();
}


FlowVis.prototype.draw = function() {
  
  var svg = this.element.append('svg')
  .attr('width', this.width + this.margin.left + this.margin.right)
  .attr('height', this.height + this.margin.top + this.margin.bottom)
  .on("mouseenter", function() {
      d3.selectAll(".flowLine").classed("highlight", false)
      d3.selectAll(".locCircleBg").classed("highlight", false)
  })
  .on("mouseleave", function() {
      d3.selectAll(".flowLine").classed("highlight", true)
      d3.selectAll(".locCircleBg").classed("highlight", true)
  });
  
  this.plot = svg.append('g')
  .attr("transform", "translate(" + this.margin.left + "," + this.margin.top + ")");

  this.flow = this.plot.append("g")
  
  // bars representing time slots
  this.timeBars = this.plot.append("g")
  .attr("transform", "translate(0," + this.height/2 + ")");

  this.locCircles = this.plot.append("g")

  this.createScales();
  this.adjustScales();
  this.addFlowLines();
  this.addLocCircles();
  this.addTimeBars();

  this.tooltip = this.plot.append("g")
  .style("display", "none");
  
  this.tooltip.append("rect")
    .attr("width", 80)
    .attr("height", 35)
    .attr("class", "tooltip")
    .style("opacity", 0.9);

  this.tooltip.append("text")
    .attr("id", "line1")
    .attr("transform", "translate(5,15)")
    .attr("class", "tooltiptext")
    
    this.tooltip.append("text")
    .attr("id", "line2")
    .attr("transform", "translate(5,30)")
    .attr("class", "tooltiptext")

    // todo: quick hack, implement better
    this.showAllFlow()
}


FlowVis.prototype.update = function(data, focusLoc, timeRange) {

  var _this = this;

  this.focusLoc    = focusLoc;
  this.timeRange   = timeRange;
  this.data        = data;
  this.locs        = this.data.locs;
  this.visitorFlow = this.data.visitorFlow;
  this.timeSlots   = this.data.timeSlots;
  
  
  // highlight location label
  d3.selectAll(".locLabel")
    .classed("focus", false)
  
  d3.selectAll(".locLabel.loc" + this.focusLoc)
    .classed("focus", true)
  
  this.adjustScales();
  this.addTimeBars();
  this.addFlowLines();
  this.addLocCircles();
}


FlowVis.prototype.createScales = function() {
  
  var _this = this;

  this.catScale = d3.scaleOrdinal()
    .domain(["Kiddie Rides", "Rides for Everyone", "Thrill Rides", "Shows & Entertainment", "Other"])
    .range(["#4daf4a", "#377eb8" , "#e41a1c", "#984ea3", "#555"].map(d => d3.hsl(d).brighter()))

  this.flowLineWidthScale = d3.scaleLinear();

  this.locPosScale = d3.scalePoint()
    .range([0, this.width]);
      
  this.locSizeScale = d3.scaleSqrt()
    .range([0, this.locCircleR]);

  this.timePosScale = d3.scaleBand()
    .range([0, this.width]);

  this.barScaleStatTop = d3.scaleLinear()
    .range([this.barHeightExp, 0]);

  this.barScaleStatBottom = d3.scaleLinear()
    .range([0, this.barHeightExp]);

  this.heatMapScale = d3.scaleSequential(d3.interpolateMagma);

  // generates lines to represent visitor flow
  this.linkGenerator = d3.linkVertical()
    .source(d => [this.locPosScale(d.locId), 
                  d.direction == "from" 
                  ? this.circleOffset 
                  : this.height - this.circleOffset]
    )
      
  this.makeLink = function(d) {
    return this.linkGenerator(d) + "V" + 
      (d.direction == "from" ? (this.height/2) : (this.height/2 + 1))
  }
}


FlowVis.prototype.adjustScales = function() {
  var _this = this

  this.locPosScale
  .domain(
    this.locs.sort( 
      function(a,b) {
        return d3.ascending(a.distance, b.distance) 
      })
      .map(d => d.locId)
    );
    
  this.timePosScale
    .domain(this.timeSlots.map(d => d.time));

  this.flowLineWidthScale
  .domain([0, d3.max(this.visitorFlow.map(d => d.n))])
  .range([0, Math.min(this.timePosScale.bandwidth(), this.locCircleR*2)]);
  
  // max size of inner location circles
  this.nToFromMaxGlobal = d3.max(this.locs, e => e.nToFromMax);
  
  this.locSizeScale
  .domain([0, this.nToFromMaxGlobal]);
  
  this.barScaleStatBottom
  .domain([0, d3.max(this.timeSlots.map(d => d.stat2))]);
    
  // default max value for heatmap
  this.heatMapMaxGlobal = d3.max(this.timeSlots, e => Math.max(e.nFromTotal, e.nToTotal));
  this.heatMapScale
    .domain([0, this.heatMapMaxGlobal]);

  this.barScaleStatTop
    .domain([0, d3.max(this.timeSlots.map(d => d.stat1))]);

  this.linkGenerator
    .target(d => [_this.timePosScale(d.time) + _this.timePosScale.bandwidth()/2, 
      d.direction == "from" 
      ? (this.height/2 - this.barHeightClp) 
      : (this.height/2 + this.barHeightClp + 1)]); // lower bars are offset by 1px
}


FlowVis.prototype.addFlowLines = function() {

  var _this = this;
  var flowLines = this.flow.selectAll(".flowLine")
    .data(this.visitorFlow)

  flowLines
    .exit()
    .remove();

  flowLines
    .enter()
      .append("path")
    .merge(flowLines)
      .attr("class", d => "flowLine flow" + d.locId + " flowt" + d.time)
      .attr("d", d => this.makeLink(d))
      .style("stroke-width", d => this.flowLineWidthScale(d.n))
      .style("stroke", d => _this.catScale(d.category));
}


FlowVis.prototype.addLocCircles = function() {
  
  var _this = this;

  // circles representing other locations

  var locCirclePairs = this.locCircles
    .selectAll(".locCirclePair")
    .data(this.locs, d => d.locId)

  locCirclePairs
    .exit()
    .remove();

    
  // animated reordering of circles and flow lines
  // disable mouseevents
  d3.selectAll(".locCirclePair")
    .attr("pointer-events", "none")
  
  locCirclePairs
    .enter()
    .append("g")
    .attr("class", d => "locCirclePair loc" + d.locId)
    .attr("transform", d => "translate(" + this.locPosScale(d.locId) + ",0)")
    .each(function(d) {

      var locClass = "loc" + d.locId

      // top row of circles
      var fromCircles = d3.select(this)
        .append("g")
        .attr("class", "fromCircle " + locClass)
        .attr("transform", d => "translate(0," + _this.circleOffset + ")");

      fromCircles
        .append("circle")
          .attr("class", "locCircleBg " + locClass)
          .attr("r", _this.locCircleR)
          .style("stroke", d => _this.catScale(d.category))

      fromCircles
        .append("circle")
          .attr("class", "locCircleFg " + locClass)
          .attr("r", d => _this.locSizeScale(d.nFrom))
          .style("fill", d => _this.catScale(d.category));

      fromCircles
        .append("text")
        .text(d => d.label)
        .attr("class", d => "locLabel loc" + d.locId + 
                            (d.locId == _this.focusLoc ? " focus" : "")
        )
        .attr("transform", "translate(-5,-25) rotate(-45)");

      // bottom row of circles
      var toCircles = d3.select(this).append("g")
        .attr("class", "toCircle " + locClass)
        .attr("transform", d => "translate(-0," + (_this.height - _this.circleOffset) + ")");

      toCircles.append("circle")
          .attr("class", "locCircleBg " + locClass)
          .attr("r", _this.locCircleR)
          .style("stroke", d => _this.catScale(d.category))

      toCircles
        .append("circle")
          .attr("class", "locCircleFg " + locClass)
          .attr("r", d => _this.locSizeScale(d.nTo))
          .style("fill", d => _this.catScale(d.category));

      toCircles
        .append("text")
        .text(d => d.label)
        .attr("class", d => "locLabel " + locClass + 
                            (d.locId == _this.focusLoc ? " focus" : "")
        )
        .attr("transform", "translate(-0,25) rotate(45)");
    })
    .merge(locCirclePairs)
      .transition()
      .duration(700)
      .attr("transform", d => "translate(" + this.locPosScale(d.locId) + ",0)")

    d3.selectAll(".toCircle").selectAll(".locCircleFg")
      .transition()
      .duration(300)
      .attr("r", d => _this.locSizeScale(d.nTo))

    d3.selectAll(".fromCircle").selectAll(".locCircleFg")
      .transition()
      .duration(300)
      .attr("r", d => _this.locSizeScale(d.nFrom))

    this.addLocCircleInteraction();
      
      setTimeout(function() {
        d3.selectAll(".locCirclePair")
        .attr("pointer-events", "auto")
        //_this.showAllFlow()
      }, 700)
      
    }
    
    
// todo: quick hack, implement more thoroughly
FlowVis.prototype.showAllFlow = function() {
  d3.selectAll(".flowLine").classed("highlight", true)
  d3.selectAll(".locCircleBg").classed("highlight", true)
}

FlowVis.prototype.hideAllFlow = function() {
  d3.selectAll(".flowLine").classed("highlight", false)
  d3.selectAll(".locCircleBg").classed("highlight", false)
}


FlowVis.prototype.addTimeBars = function() {
  
  var _this = this;

  // top row of bars
  var timeBarTop = this.timeBars
    .selectAll(".timeBarTop")
    .data(this.timeSlots, d => d.time)
 
    timeBarTop
      .exit()
      .remove();
      
      timeBarTop
      .enter()
        .append("rect")
        .attr("class", "timeBarTop")
        .attr("height", this.barHeightClp)
        .attr("y", this.barHeightExp - this.barHeightClp)
        .attr("transform", "translate(0," + (-this.barHeightExp) + ")")
        .style("fill", "black")
      .merge(timeBarTop)
        .attr("width", this.timePosScale.bandwidth())
        .attr("x", d => _this.timePosScale(d.time))
        .transition()
        .duration(100)
        .style("fill", d => _this.heatMapScale(d.nFromTotal))
      
      // bottom row of bars
      var timeBarBottom = this.timeBars
      .selectAll(".timeBarBottom")
      .data(this.timeSlots, d => d.time)
      
    timeBarBottom
      .exit()
      .remove();
      
    timeBarBottom
      .enter()
      .append("rect")
      .attr("class", "timeBarBottom")
      .attr("height", this.barHeightClp)
      .attr("y", 1) // lower bars are offset by one
      .style("fill", "black")
    .merge(timeBarBottom)
      .attr("width", this.timePosScale.bandwidth()) 
      .attr("x", d => _this.timePosScale(d.time))
      .transition()
      .duration(100)
      .style("fill", d => _this.heatMapScale(d.nToTotal))

    this.addTimeBarInteraction();
}


FlowVis.prototype.addTimeBarInteraction = function() {

  _this = this;

  this.timeBars
    //.on("click", toggleBarExpansion) # todo: disabled for submission, add axis and proper transition behavior
    .on("mouseout", hoverTimeBarOut)
    
    d3.selectAll(".timeBarTop, .timeBarBottom")
    .on("mouseover", hoverTimeBarIn)
    .on("mousemove", hoverTimeBarMove)

  function hoverTimeBarMove(d) {
    var xPos = d3.mouse(this.parentNode)[0];
    xPos = xPos > _this.width - 120 ? xPos - 100 : xPos + 30

    var yPos = d3.mouse(this.parentNode)[1] + (_this.height/2) - 15;

    
    _this.tooltip.attr("transform", "translate(" + xPos + "," + yPos + ")");
    _this.tooltip.select("#line1").text(d.start);
    _this.tooltip.select("#line2").text(d.end);
  }

  // Interaction with time bar
  function hoverTimeBarIn(d) {

    // show tooltip
    _this.tooltip.style("display", null)

    // highlight corresponding flow lines
    d3.selectAll(".flowt" + d.time)
      .classed("highlight", true)
      .moveToFront()

    // highlight all locations sending/receiving visitors at that time point
    Object.keys(d.nFrom).forEach(function(locId) {
        d3.selectAll(".fromCircle")
          .selectAll(".locCircleBg.loc" + locId + ", .locLabel.loc" + locId)
          .classed("highlight", true)
        })
        Object.keys(d.nTo).forEach(function(locId) {
          d3.selectAll(".toCircle")
          .selectAll(".locCircleBg.loc" + locId + ", .locLabel.loc" + locId)
          .classed("highlight", true)
    })

    // rescale inner circles
    _this.locSizeScale.domain([0, d.nToFromMax])

    d3.selectAll(".fromCircle").selectAll(".locCircleFg")
      .transition()
      .duration(300)
      .attr("r", e => d.nFrom[e.locId] === undefined
                      ? _this.locSizeScale(0)
                      : _this.locSizeScale(d.nFrom[e.locId]))

    d3.selectAll(".toCircle").selectAll(".locCircleFg")
      .transition()
      .duration(300)
      .attr("r", e => d.nTo[e.locId] === undefined
                      ? _this.locSizeScale(0)
                      : _this.locSizeScale(d.nTo[e.locId]))
  }

  function hoverTimeBarOut(d) {

    // remove hghlights and tooltip
    d3.selectAll(".locLabel, .locCircleBg, .flowLine")
      .classed("highlight", false)

    _this.tooltip
    .style("display", "none")

    // reset circle size
    _this.locSizeScale.domain([0, _this.nToFromMaxGlobal])
    d3.selectAll(".toCircle").selectAll(".locCircleFg")
      .transition()
      .duration(300)
      .attr("r", d => _this.locSizeScale(d.nTo))

    d3.selectAll(".fromCircle").selectAll(".locCircleFg")
      .transition()
      .duration(300)
      .attr("r", d => _this.locSizeScale(d.nFrom))
  }  

  function toggleBarExpansion(d) {

    _this.barsExpanded ? collapseBars(d) : expandBars(d)
    _this.barsExpanded = !_this.barsExpanded
  }

  function expandBars(d) {

    d3.selectAll(".timeBarTop")
      .transition()
      .ease(d3.easeQuad)
      .duration("300")
      .attr("y", d => _this.barScaleStatTop(d.stat1))
      .attr("height", d => _this.barHeightExp - _this.barScaleStatTop(d.stat1))
      .style("fill", "black");

    d3.selectAll(".timeBarBottom")
      .transition()
      .ease(d3.easeQuad)
      .duration("300")
      .attr("height", d => _this.barScaleStatBottom(d.stat2))
      .style("fill", "teal");
  }

  function collapseBars(d) {

    d3.selectAll(".timeBarTop")
      .transition()
      .ease(d3.easeExp)
      .duration("500")
      .attr("y", _this.barHeightExp - _this.barHeightClp)
      .attr("height", _this.barHeightClp)
      .style("fill", d => _this.heatMapScale(d.nFromTotal));

    d3.selectAll(".timeBarBottom")
      .transition()
      .ease(d3.easeExp)
      .duration("500")
      .attr("height", _this.barHeightClp)
      .style("fill", d => _this.heatMapScale(d.nToTotal));
  }
}


FlowVis.prototype.addLocCircleInteraction = function() {
  _this = this;

  d3.selectAll(".locCirclePair")
    .on("mouseover", hoverLocCirclesIn)
    .on("mouseout", hoverLocCirclesOut)
    .on("click", d => _this.onRefocus(d.locId))

  // Interaction with circles
  function hoverLocCirclesIn(d) {

    d3.select(this).selectAll(".locCircleBg, .locLabel")
      .classed("highlight", true) 
   
    d3.selectAll(".flow" + d.locId)
      .classed("highlight", true)
      .moveToFront()
  
    // update heatmap on bars with selected location
    if (!_this.barsExpanded) {
      
      _this.heatMapScale.domain([0, d.nToFromMaxBin])

      d3.selectAll(".timeBarTop")
        .transition()
        .duration(200)
        .style("fill", e => e.nFrom[d.locId] === undefined 
                            ? _this.heatMapScale(0) 
                            : _this.heatMapScale(e.nFrom[d.locId])) 

      d3.selectAll(".timeBarBottom")
        .transition()
        .duration(200)
        .style("fill", e => e.nTo[d.locId] === undefined 
                            ? _this.heatMapScale(0) 
                            : _this.heatMapScale(e.nTo[d.locId]))
    }
  }
  
  function hoverLocCirclesOut(d) {
    
    d3.selectAll(".locCircleBg, .flowLine, .locLabel")
      .classed("highlight", false)
  
      // reset heatmap on bars
      if (!_this.barsExpanded) {
        _this.heatMapScale.domain([0, _this.heatMapMaxGlobal])
        d3.selectAll(".timeBarTop")
          .transition()
          .delay(100)
          .duration(200)
          .style("fill", d => _this.heatMapScale(d.nFromTotal));
        d3.selectAll(".timeBarBottom")
          .transition()
          .delay(100)
          .duration(200)
          .style("fill", d => _this.heatMapScale(d.nToTotal));
    }
  } 
}