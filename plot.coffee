# TODO GraphZoom:
# can this be vanilla module?
# option for legend position, e.g., "nw"

# Imported utility functions
{zeros, rep, end} = $blab.array

class GraphZoom

    constructor: (@spec) ->
                        
        sel = "##{@spec.id}"
        @container = $ sel
        @setMargins()
        
        # d3/SVG container
        @container.empty()
        svg = d3.select(sel)
            .append("svg")
            .attr("width", @cw)
            .attr("height", @cw)
            
        svg.append("defs")
            .append("clipPath")
            .attr("id", "clip")
            .append("rect")
            .attr("width", @width)
            .attr("height", @height)
        
        # TODO: autolimits feature
        
        @focus = new Axes
            svg: svg
            width: @width
            height: @height
            margin: @margin
            limits: @spec.limits
            xf: @spec.xf
            yf: @spec.yf
            ylabel: @spec.ylabel
                
        @context = new Axes  # ZZZ perhaps different class so can set specific stuff
            svg: svg
            width: @width
            height: @heightContext
            margin: @marginContext
            limits: @spec.limits
            yAxis: false
            xf: @spec.xf
            yf: @spec.yf

        @brush = d3.svg.brush().x(@context.x).on("brush", (=> @brushed()))

        @context.axes.append("g")
            .attr("class", "x brush")
            .call(@brush).selectAll("rect")
            .attr("y", -6)
            .attr("height", @heightContext + 7)
            
    setMargins: ->
        @cw = @container.width()
        @ch = @container.height()
        
        @margin = @spec.margin ? {}
        @marginContext = @spec.marginContext ? {}
        
        @margin.top ?= 10
        @margin.left ?= 60
        @margin.right ?= 20
        @margin.bottom ?= 100  #
        
        @marginContext.top ?= @ch - (@margin.bottom - 30)
        @marginContext.left ?= @margin.left
        @marginContext.right ?= @margin.right
        @marginContext.bottom ?= 20
        
        @width = @cw - @margin.left - @margin.right
        @height = @ch - @margin.top - @margin.bottom
        @heightContext = @ch - @marginContext.top - @marginContext.bottom
        
    setBrush: (extent) ->
        @context.axes.select(".brush").call(@brush.extent(extent))
        @brushed()
            
    lines: (spec) ->
        # Plots line in focus axes, and another in context axes.
        @focus.lines spec
        @context.lines spec
        
    text: (spec) ->
        @focus.text spec
                
    brushed: ->
        xd = if @brush.empty() then @context.x.domain() else @brush.extent()
        @focus.zoom xd
        
class Axes

    constructor: (@spec) ->
        # spec: width, height, margin, class
        
        @isPreview = @spec.yAxis is false
        
        @width = @spec.width
        @height = @spec.height
        @margin = @spec.margin  # top, right, bottom, left
        
        @axes = @spec.svg.append("g")
            .attr("class", spec.class)
            #.attr("class", "grid")
            .attr("transform", "translate(#{@margin.left}, #{@margin.top})")
              
        @x = d3.scale.linear().range([0, @width])  # ZZZ time in spec?
        @y = d3.scale.linear().range([@height, 0])
        
        # Functions to map data to (x, y)
        @xf = @spec.xf
        @yf = @spec.yf
        
        # Functions to map data to pixel (x, y)
        @xd = (d) => @x @xf(d)
        @yd = (d) => @y @yf(d)
        
        @xAxis = d3.svg.axis()
            .scale(@x)
            .orient("bottom")
            .tickFormat(d3.format("d"))  # No commas - ZZZ should be in spec
        unless @isPreview
            @yAxis = d3.svg.axis()
                .scale(@y)
                .orient("left")
        
        @area = d3.svg.area().x(@xd).y0(@height).y1(@yd)
        
        @limits(@spec.limits) if @spec.limits
        
        @legend = new Legend @axes unless @isPreview
                                
    limits: (spec) ->
        xLim = [@xf(spec[0]), @xf(spec[1])]
        yLim = [@yf(spec[0]), @yf(spec[1])]

        @x.domain xLim
        @y.domain yLim

        # ZZZ need simpler way than this.  Does path need datum?
        datum = [{}, {}]
        keys = (key for key of spec[0])
        [k0, k1] = keys
        datum[0][k0] = spec[0][k0]
        datum[0][k1] = spec[1][k1]  # Note spec[1] here
        datum[1][k0] = spec[1][k0]
        datum[1][k1] = spec[1][k1]        
        
        #datum = spec
        @axes.append("path")
            .datum(datum)
            #.datum(spec.limDatum)
            .attr("class", "area")
            .attr "d", @area
            
        @xa = @axes.append("g")
            .attr("class", "x axis")
            .attr("transform", "translate(0," + @height + ")")
            .call @xAxis
        
        unless @isPreview
            @ya = @axes.append("g")
                .attr("class", "y axis")
                .call @yAxis
            @grid()
        
        @labels()
                
    grid: ->
        
        gl = (c, d) =>
            g = @axes.selectAll("line.#{c}").data(d.ticks())
            g.enter()
                .append("line")
                .attr class: "grid #{c}"
            g.exit().remove()
            g
            
        gl("horizontalGrid", @y).attr
            x1: 0
            x2: @width
            y1: (d) => @y(d)
            y2: (d) => @y(d)
        gl("verticalGrid", @x).attr
            x1: (d) => @x(d)
            x2: (d) => @x(d)
            y1: 0
            y2: @height
            
    labels: ->
        if false #@isPreview
            @xa.append("text")
                .attr("class", "x label")
                .attr("stroke", "red") 
                .attr("text-anchor", "middle")
                .attr("x", @width/2)
                .attr("y", 30)
                .text("x label")
        if @spec.ylabel
            @ya.append("text")
                .attr("class", "y label")
                .attr("fill", "black")
                .attr("text-anchor", "middle")
                .attr("x", -@height/2)
                .attr("y", -35)
                .attr("transform", "rotate(-90)")
                .attr("dy", "0em")
                .text(@spec.ylabel)        

    zoom: (xd) ->
        @x.domain(xd)
        @lines @lineSpec
        @text @textSpec if @textSpec
        @axes.select(".area").attr "d", @area
        @axes.select(".x.axis").call @xAxis
        @grid()
        
    lines: (@lineSpec) ->
        paths = @axes.selectAll(".line").data(@lineSpec)
        paths.enter()
            .append("path")
            .attr("class", "line")
            .attr("fill", "none")
        paths.exit().remove()
        xd = (d) => @xd d
        yd = (d) => @yd d
        width = (d) => if @yAxis then (d.width ? 2) else (d.contextWidth ? 2)
        paths
            .attr("stroke", (d) -> d.color ? "white")
            .attr("stroke-width", width)
            .datum((d) -> d.data)
            .attr("d", d3.svg.line().interpolate("monotone").x(xd).y(yd))
        
        @legend?.draw @lineSpec
            
    text: (@textSpec) ->
        xd = (d) =>
            p = d.pos
            if $.isArray(p) then p[0] else @xd p
        yd = (d) =>
            p = d.pos
            if $.isArray(p) then p[1] else @yd p
        text = @axes.selectAll(".axes_text").data(@textSpec)
        text.enter()
            .append("text")
            .attr("class", "axes_text")
        text
            .attr("x", xd)
            .attr("y", yd)
            .attr("dx", (d) -> d.dx ? "0em")
            .attr("dy", (d) -> d.dy ? "0em")
            .attr("fill", (d) -> d.color ? "white")
            .text((d) -> d.text)
        text.exit().remove()
            
class Legend

    top = 20
    left = 20
    keySize = 10
    keySpacing = 10
    textGap = 10
        
    constructor: (@container) ->

        @legend = @container.append("g")
            .attr("class", "legend")
            .attr("transform", "translate(#{left}, #{top})")
            
    draw: (@lineSpec) ->
        
        y = (i) -> i*(keySize + keySpacing)
        
        keys = @legend.selectAll("rect").data(@lineSpec)
        keys.enter()
            .append("rect")
            .attr("width", keySize)  # ZZZ CSS?
            .attr("height", keySize)
        keys
            .attr("y", (d, i) -> y(i))
            .style("fill", (d, i) -> d.color)
            
        text = @legend.selectAll("text").data(@lineSpec)
        text.enter()
            .append("text")
            .attr("x", keySize + textGap)
            .attr("dy", ".35em")
            .style("fill", "white")
        text
            .attr("y", (d, i) -> y(i) + keySize/2)
            .text((d) -> d.label)
            
$blab.GraphZoom = GraphZoom  # Export

