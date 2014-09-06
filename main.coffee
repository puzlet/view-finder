# Import
GraphZoom = $blab.GraphZoom

graph = new GraphZoom
    id: "test_graph_container"
    xf: (d) -> d.x
    yf: (d) -> d.y
    limits: [
        {x: -10, y: -15}
        {x: 10, y: 15}
    ]
    ylabel: "Some y label"

series = (x, y) ->
    (x: xp, y: y[idx] for xp, idx in x)

l1 =
    data: series([-10..10], [-10..10])
    label: "My Plot"
    color: "yellow"
    width: 2

console.log "l1", l1

graph.lines [l1]
