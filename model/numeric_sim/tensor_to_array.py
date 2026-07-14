"""
Manejo de Simulaciones Numéricas.

Adapta los tensores crudos del modelo (matrices de atención, activaciones,
vectores semánticos) hacia arreglos/grafos numéricos que después consume
el ViewModel (Adaptador Visual) para alimentar a VisPy.

Importante: este módulo pertenece al Modelo, NO al ViewModel. Solo hace
la conversión numérica (torch.Tensor -> numpy.ndarray / estructuras de
grafo); el adaptador que prepara la estructura específica para la Vista
vive en viewmodel/visual_adapter.py.

TODO:
- attention_matrix_to_numpy(tensor) -> np.ndarray
- embeddings_to_graph(tensor) -> estructura de grafo (nodos/aristas)
"""
