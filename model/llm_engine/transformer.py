"""
Motor LLM — Arquitectura Transformer (Model, capa "Cerebro IA").

Responsabilidad (según sección 4.9.1 del documento de diseño):
Contiene la implementación matemática y estructural de la arquitectura
Transformer (ej. variante nano-GPT). Se encarga de instanciar el modelo,
ejecutar la inferencia y coordinar tokenización + atención + muestreo.

Este módulo NO debe importar nada de `view/` ni `viewmodel/`.

TODO (próxima sesión):
- Definir clase TransformerModel(nn.Module).
- Bloques: embeddings, positional encoding, N x (self-attention + FFN), capa de salida.
"""
