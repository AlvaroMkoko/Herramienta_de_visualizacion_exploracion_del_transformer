"""
Adaptador Visual.

Transforma los datos numéricos ya convertidos por
model/numeric_sim/tensor_to_array.py en estructuras específicas y
optimizadas para el consumo directo de VisPy/QML (ej. formatos de
buffer, listas de coordenadas, mapas de color).

TODO:
- adapt_attention_map(np_array) -> estructura para view/canvas/attention_canvas.py
- adapt_embeddings(np_array) -> estructura para view/canvas/vector_canvas.py
"""
