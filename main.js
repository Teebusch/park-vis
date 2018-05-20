var ParkVis = function(data) {

  //var _this = this;

  this.width     = 1500;
  this.focusLoc  = "EN";
  
  this.data      = data;
  this.timeRange = d3.extent(this.data.timeSlots.map(d => d.time));
  this.data_flt  = this.filterData(this.data, this.focusLoc, this.timeRange);
        
  this.updateInfoText();

  this.contextVis = new ContextVis({
    element:    d3.select("#contextVis"),
    dataTotal:  this.data.context,
    dataFocus:  this.data_flt.timeSlotsLocFlt,
    timeRange:  this.timeRange,
    height:     300,
    width:      1000,
    margin:     {top: 30, right: 30, bottom: 30, left: 50},
    onBrush:    d => this.changeTimeRange(d)
  });

  this.locationVis = new LocationVis({
    element:    d3.select("#locationVis"),
    data:       this.data.locs,
    xyData:     this.data_flt.xyData,
    focusLoc:   this.focusLoc,
    timeRange:  this.timeRange,
    height:     300,
    width:      300,
    margin:     {top: 20, right: 20, bottom: 20, left: 20},
    onClickLoc: d => this.changeFocusLoc(d)
  });
  
  this.flowVis = new FlowVis({
    element:    d3.select("#flowVis"),
    data:       this.data_flt,
    focusLoc:   this.focusLoc,
    timeRange:  this.timeRange,
    height:     850,
    width:      1500,
    margin:     {top: 90, right: 90, bottom: 50, left: 30},
    onRefocus:  d => this.changeFocusLoc(d)
  });  
}

ParkVis.prototype.filterData = function() {

  _this = this;

  var visitorFlow = this.data.visitorFlow;
  var timeSlots   = this.data.timeSlots;
  var locs        = this.data.locs;
  var xyData      = this.data.xyData;

  xyData = xyData.filter(
    e => //e.timeBin >= _this.timeRange[0] &
         //e.timeBin <= _this.timeRange[1] &
         e.timeBin == _this.timeRange[0]
    );
  
  // todo: aggregate

  
  visitorFlow = visitorFlow.filter(
    e => e.focusLoc == _this.focusLoc
         & (e.n > 0)
         & e.time >= _this.timeRange[0]
         & e.time <= _this.timeRange[1]
    );
  
  timeSlotsLocFlt = timeSlots.filter(
    e => e.focusLoc == _this.focusLoc
  )

  timeSlots = timeSlotsLocFlt.filter(
    e => e.time >= _this.timeRange[0] &
         e.time <= _this.timeRange[1]
    )

  var distances = this.data.distmat.find(e => e.locId == this.focusLoc)

  locs = locs.map(function(e) {
      var sel   = visitorFlow.filter(g => g.locId == e.locId);
      var nFrom = sel.filter(g => g.direction == "from").map(g => g.n)
      var nTo   = sel.filter(g => g.direction == "to").map(g => g.n)

      // max n moving from/to the loc. at any given time bin
      function safeMax(a,b) {
        a = (a == undefined ? 0 : a);
        b = (b == undefined ? 0 : b);
        return Math.max(a, b)
      }

      e.nToFromMaxBin = safeMax(d3.max(nFrom), d3.max(nTo)) 

      // total and max n moving from/to the two locations  
      e.nFrom      = d3.sum(nFrom)
      e.nTo        = d3.sum(nTo)
      e.nToFromMax = Math.max(e.nFrom, e.nTo) 

      // distance to focus location (for sorting the circles)     
      if(e.locId == "OP" | _this.focusLoc == "OP") { 
        e.distance = Infinity 
      } else { e.distance = distances[e.locId]; }

      if(e.locId == _this.focusLoc) { e.distance = -Infinity }

      return e
    })

  return {
    xyData: xyData,
    timeSlotsLocFlt: timeSlotsLocFlt,
    timeSlots: timeSlots,
    visitorFlow: visitorFlow,
    locs: locs
  }
};


ParkVis.prototype.changeFocusLoc = function(newFocusLoc) {
  console.log(newFocusLoc)

  this.focusLoc = newFocusLoc;
  this.data_flt = this.filterData();
  this.contextVis.update(this.data_flt.timeSlotsLocFlt);
  this.flowVis.update(this.data_flt, this.focusLoc, this.timeRange);
  this.locationVis.update(this.data_flt.xyData, this.focusLoc, this.timeRange);
  this.updateInfoText();
}


ParkVis.prototype.changeTimeRange = function(newTimeRange) {
  
  if (newTimeRange[0] != this.timeRange[0] | newTimeRange[1] != this.timeRange[1]) {
    this.timeRange = newTimeRange;
    this.data_flt = this.filterData();

    this.flowVis.update(this.data_flt, this.focusLoc, this.timeRange);
    this.locationVis.update(this.data_flt.xyData, this.focusLoc, this.timeRange);
    this.updateInfoText();
  }
}


ParkVis.prototype.updateInfoText = function() {

  var _this = this

  var focusLabel = this.data.locs.find(d => d.locId == _this.focusLoc).label;

  var t1Label = this.data.context.find(d => d.timeBin == _this.timeRange[0]).start;
  var t2Label = this.data.context.find(d => d.timeBin == _this.timeRange[1]).end;

  d3.selectAll(".focusLocName").text(focusLabel)    
  d3.select("#rangeStart").text(t1Label)  
  d3.select("#rangeEnd").text(t2Label) 
}


d3.selection.prototype.moveToFront = function() {  
  return this.each(function(){
    this.parentNode.appendChild(this);
  })
}


loadData = async function() {
  var formatTime = d3.utcFormat("%A %-H%:%M");
  var formatTimeShort = d3.utcFormat("%a %-H%:%M");
  
  // run once on page load

  var locs = await d3.csv("locations.csv");

  var xyData = await d3.csv("xy.csv");

  var distmat = await d3.csv("distmat.csv", function(e) {
    Object.keys(e).forEach(function(k) {
      if(k != "locId") {
        e[k] = +e[k]
      }
    });
    return(e)
  });

  var context = await d3.csv("context.csv", function(e) {
    e.totalVisitors = + e.totalVisitors;
    e.timeBin = + e.timeBin;
    e.start = formatTime(d3.isoParse(e.start));
    e.end = formatTime(d3.isoParse(e.end));
    return(e)
  });
  
  var timeSlots = await d3.json("timeSlots.json")
  
  timeSlots = timeSlots.map(function(e) {
    e.start = formatTimeShort(d3.isoParse(e.start + "Z")); // todo: fix in R
    e.end = formatTimeShort(d3.isoParse(e.end + "Z"));
    e.timeBinLabel = e.start + " to" + e.end;
    return(e)
  });

  var visitorFlow = await d3.csv("flow.csv", function(e) {
    e.time = + e.time;
    e.n = + e.n;
    return e
  });
  
  return {
    xyData:      xyData,
    context:     context,
    timeSlots:   timeSlots,
    visitorFlow: visitorFlow,
    locs:        locs,
    distmat:     distmat
  }
};



loadData().then( d => new ParkVis(d) ) 

