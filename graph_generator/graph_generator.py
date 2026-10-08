import sqlite3
from pyvis.network import Network

def generate_html_graph(db_path, output_html="verilog_graph.html"):
    # 1. Connect to SQLite database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Fetch nodes
    cursor.execute("SELECT id, kind, name FROM nodes")
    nodes_data = cursor.fetchall()

    # Fetch edges
    cursor.execute("SELECT src, dst, kind FROM edges")
    edges_data = cursor.fetchall()
    conn.close()

    # 2. Initialize Pyvis Network
    net = Network(height="900px", width="100%", directed=True, bgcolor="#1e1e2e", font_color="#ffffff")
    
    # Physics layout configuration for DAGs/hierarchical graphs
    net.force_atlas_2based(gravity=-50, central_gravity=0.01, spring_length=100, spring_strength=0.08)

    # Color mapping for node kinds
    kind_colors = {
        'module': '#f38ba8',    # Red/Pink
        'instance': '#89b4fa',  # Blue
        'process': '#a6e3a1',   # Green
        'port': '#f9e2af',      # Yellow
        'signal': '#cba6f7',    # Purple
        'file': '#f5c2e7',      # Light Pink
        'macro': '#94e2d5'       # Teal
    }

    # 3. Add nodes
    for node_id, kind, name in nodes_data:
        color = kind_colors.get(kind, '#89dceb')
        display_name = name if name else node_id.split('::')[-1]
        
        # Title appears on hover in the interactive HTML view
        tooltip = f"<b>ID:</b> {node_id}<br><b>Kind:</b> {kind}<br><b>Name:</b> {display_name}"
        
        net.add_node(
            node_id,
            label=display_name,
            title=tooltip,
            color=color,
            shape="dot",
            size=18
        )

    # 4. Add edges
    edge_colors = {
        'instantiates': '#f38ba8',
        'declares': '#f38ba8',
        'drives': '#89b4fa',
        'connects': '#89b4fa',
        'reads': '#a6e3a1'
    }

    for src, dst, kind in edges_data:
        color = edge_colors.get(kind, '#6c7086')
        net.add_edge(
            src,
            dst,
            title=f"Kind: {kind}",
            color=color,
            arrows="to",
            width=1.5
        )

    # 5. Save HTML interactive graph
    net.write_html(output_html)
    print(f"Interactive HTML graph successfully generated: {output_html}")

if __name__ == "__main__":
    # Replace 'your_database.db' with your SQLite file path
    generate_html_graph(r'C:\Users\AdamSbane\Downloads\graph_generator\graph.db')