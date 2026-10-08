"""
Generate Interactive Call Graph Visualization
Shows function call relationships from Scalpel analysis
"""

import json
import os

def generate_call_graph(dataflow_file='scalpel_complete_dataflow.json', output_file='call_graph.html'):
    """Generate interactive call graph visualization."""
    
    # Load dataflow data
    with open(dataflow_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    call_graph = data.get('call_graph', {})
    metadata = data.get('metadata', {})
    
    if not call_graph:
        print("⚠️  No call graph data found. Run analysis with Scalpel enabled.")
        return
    
    # Build graph structure
    nodes = []
    links = []
    node_map = {}
    
    # Create nodes for all functions
    node_id = 0
    all_functions = set()
    for caller, calls in call_graph.items():
        all_functions.add(caller)
        for call in calls:
            all_functions.add(call['function'])
    
    for func_name in sorted(all_functions):
        node_map[func_name] = node_id
        # Count calls
        outgoing = len([c for caller, calls in call_graph.items() if caller == func_name for _ in calls])
        incoming = len([c for caller, calls in call_graph.items() for c in calls if c['function'] == func_name])
        
        nodes.append({
            'id': node_id,
            'name': func_name,
            'outgoing': outgoing,
            'incoming': incoming,
            'total_calls': outgoing + incoming
        })
        node_id += 1
    
    # Create links
    for caller, calls in call_graph.items():
        if caller not in node_map:
            continue
        source_id = node_map[caller]
        
        for call in calls:
            called_func = call['function']
            if called_func in node_map:
                target_id = node_map[called_func]
                links.append({
                    'source': source_id,
                    'target': target_id,
                    'caller': caller,
                    'callee': called_func,
                    'line': call.get('line', 0),
                    'path_conditions': call.get('path_conditions', [])
                })
    
    # Generate HTML
    html_content = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Interactive Call Graph</title>
    <script src="https://d3js.org/d3.v7.min.js"></script>
    <style>
        body {{
            margin: 0;
            padding: 20px;
            font-family: Arial, sans-serif;
            background: #1a1a1a;
            color: #fff;
        }}
        #controls {{
            position: fixed;
            top: 10px;
            right: 10px;
            background: rgba(0,0,0,0.8);
            padding: 15px;
            border-radius: 8px;
            z-index: 1000;
            max-width: 300px;
        }}
        #controls button {{
            background: #4ECDC4;
            color: #1a1a1a;
            border: none;
            padding: 8px 15px;
            margin: 5px;
            border-radius: 4px;
            cursor: pointer;
            font-weight: bold;
            display: block;
            width: 100%;
        }}
        #controls button:hover {{
            background: #95E1D3;
        }}
        #info {{
            position: fixed;
            bottom: 10px;
            left: 10px;
            background: rgba(0,0,0,0.9);
            padding: 15px;
            border-radius: 8px;
            max-width: 400px;
            display: none;
        }}
        .node circle {{
            fill: #4ECDC4;
            stroke: #fff;
            stroke-width: 2px;
            cursor: pointer;
        }}
        .node text {{
            font-size: 11px;
            fill: #fff;
            pointer-events: none;
        }}
        .link {{
            fill: none;
            stroke: #666;
            stroke-opacity: 0.6;
            stroke-width: 2px;
        }}
        .link:hover {{
            stroke: #FFD93D;
            stroke-opacity: 1;
            stroke-width: 3px;
        }}
    </style>
</head>
<body>
    <div id="controls">
        <h3 style="margin-top: 0; color: #4ECDC4;">Call Graph</h3>
        <button onclick="resetZoom()">Reset Zoom</button>
        <button onclick="exportSVG()">Export SVG</button>
        <p style="font-size: 11px; margin-top: 10px;">
            <strong>Click</strong> nodes to see details<br>
            <strong>Hover</strong> edges to see call info<br>
            <strong>Drag</strong> to pan, <strong>Scroll</strong> to zoom
        </p>
    </div>
    
    <div id="info">
        <h4 id="info-title">Function Details</h4>
        <div id="info-content"></div>
    </div>
    
    <svg id="graph"></svg>
    
    <script>
        const nodes = {json.dumps(nodes)};
        const links = {json.dumps(links)};
        
        const width = window.innerWidth;
        const height = window.innerHeight;
        
        const svg = d3.select("#graph")
            .attr("width", width)
            .attr("height", height);
        
        const g = svg.append("g");
        
        const zoom = d3.zoom()
            .scaleExtent([0.1, 4])
            .on("zoom", (event) => {{
                g.attr("transform", event.transform);
            }});
        
        svg.call(zoom);
        
        const sizeScale = d3.scaleSqrt()
            .domain([0, d3.max(nodes, d => d.total_calls)])
            .range([8, 25]);
        
        const simulation = d3.forceSimulation(nodes)
            .force("link", d3.forceLink(links).id(d => d.id).distance(150))
            .force("charge", d3.forceManyBody().strength(-500))
            .force("center", d3.forceCenter(width / 2, height / 2))
            .force("collision", d3.forceCollide().radius(d => sizeScale(d.total_calls) + 10));
        
        const link = g.append("g")
            .selectAll("line")
            .data(links)
            .enter().append("line")
            .attr("class", "link")
            .on("mouseover", function(event, d) {{
                showLinkInfo(d);
            }})
            .on("mouseout", function() {{
                hideInfo();
            }});
        
        const node = g.append("g")
            .selectAll("g")
            .data(nodes)
            .enter().append("g")
            .attr("class", "node")
            .call(d3.drag()
                .on("start", dragstarted)
                .on("drag", dragged)
                .on("end", dragended)
            )
            .on("click", function(event, d) {{
                showNodeInfo(d);
            }});
        
        node.append("circle")
            .attr("r", d => sizeScale(d.total_calls));
        
        node.append("text")
            .text(d => d.name.length > 20 ? d.name.substring(0, 17) + "..." : d.name)
            .attr("dx", d => sizeScale(d.total_calls) + 5)
            .attr("dy", 4);
        
        simulation.on("tick", () => {{
            link
                .attr("x1", d => d.source.x)
                .attr("y1", d => d.source.y)
                .attr("x2", d => d.target.x)
                .attr("y2", d => d.target.y);
            
            node.attr("transform", d => `translate(${{d.x}},${{d.y}})`);
        }});
        
        function dragstarted(event, d) {{
            if (!event.active) simulation.alphaTarget(0.3).restart();
            d.fx = d.x;
            d.fy = d.y;
        }}
        
        function dragged(event, d) {{
            d.fx = event.x;
            d.fy = event.y;
        }}
        
        function dragended(event, d) {{
            if (!event.active) simulation.alphaTarget(0);
            d.fx = null;
            d.fy = null;
        }}
        
        function showNodeInfo(d) {{
            const info = document.getElementById("info");
            const title = document.getElementById("info-title");
            const content = document.getElementById("info-content");
            
            title.textContent = `Function: ${{d.name}}`;
            content.innerHTML = `
                <strong>Calls:</strong> ${{d.outgoing}}<br>
                <strong>Called by:</strong> ${{d.incoming}}<br>
                <strong>Total:</strong> ${{d.total_calls}}
            `;
            info.style.display = "block";
        }}
        
        function showLinkInfo(d) {{
            const info = document.getElementById("info");
            const title = document.getElementById("info-title");
            const content = document.getElementById("info-content");
            
            title.textContent = `Call: ${{d.caller}} → ${{d.callee}}`;
            let html = `<strong>Line:</strong> ${{d.line}}<br>`;
            
            if (d.path_conditions && d.path_conditions.length > 0) {{
                html += `<br><strong style="color: #FFD93D;">Path Conditions:</strong><br>`;
                d.path_conditions.forEach(cond => {{
                    html += `  • ${{cond}}<br>`;
                }});
            }}
            
            content.innerHTML = html;
            info.style.display = "block";
        }}
        
        function hideInfo() {{
            document.getElementById("info").style.display = "none";
        }}
        
        function resetZoom() {{
            svg.transition().duration(750).call(
                zoom.transform,
                d3.zoomIdentity
            );
        }}
        
        function exportSVG() {{
            const svgData = new XMLSerializer().serializeToString(svg.node());
            const blob = new Blob([svgData], {{type: "image/svg+xml"}});
            const url = URL.createObjectURL(blob);
            const link = document.createElement("a");
            link.href = url;
            link.download = "call_graph.svg";
            link.click();
        }}
    </script>
</body>
</html>
"""
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"✅ Call graph visualization generated: {output_file}")
    print(f"   Shows {len(nodes)} functions and {len(links)} call relationships")
    print(f"   Open in browser to explore!")

if __name__ == '__main__':
    generate_call_graph()

