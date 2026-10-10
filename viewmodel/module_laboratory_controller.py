"""Laboratorios especializados alimentados por el Transformer activo.

Cada laboratorio recorre únicamente las operaciones del módulo estudiado.
Los tensores proceden del mismo forward que usa el modelo y el modo de
entrenamiento calcula gradientes con ``autograd.grad``: nunca ejecuta un
optimizador ni modifica pesos o buffers ``.grad`` del modelo compartido.
"""

from __future__ import annotations

import math
from typing import Any

from PySide6.QtCore import Property, QObject, Signal, Slot
import torch
import torch.nn.functional as F

from model.motor_llm.muestreo import aplicar_temperatura, filtrar_top_k, filtrar_top_p
from .visual_adapter import construir_detalle_forward, resumir_paso_inferencia


_LEGACY_PANEL_KEYS: dict[str, tuple[str, ...]] = {
    "module_1": ("token_ids", "padding_mask"),
    "module_2": ("embedding", "position", "embedding_plus_position"),
    "module_3": ("q", "k", "v", "scores", "attention_weights", "attention_output"),
    "module_4": ("head_attention", "head_output", "concatenated", "projected"),
    "module_5": ("encoder_input", "attention_residual", "ffn_hidden", "encoder_output"),
    "module_6": (
        "causal_mask",
        "masked_attention",
        "cross_attention",
        "decoder_output",
    ),
    "module_7": ("logits", "probabilities"),
    "module_8": ("tokens", "embedding", "encoder", "decoder", "logits"),
}


_BEHAVIOR: dict[str, dict[str, str]] = {
    "module_1": {
        "training": "Para hacer visible PAD, añade una segunda secuencia didáctica truncada y etiquetada; estas operaciones no tienen parámetros entrenables.",
        "inference": "Tokeniza un prompt y limita su longitud; normalmente procesa una sola secuencia sin PAD.",
    },
    "module_2": {
        "training": "La fila de embedding recibe gradiente y dropout está activo; la codificación sinusoidal permanece fija.",
        "inference": "Consulta los embeddings aprendidos, suma la posición fija y desactiva dropout.",
    },
    "module_3": {
        "training": "Q, K y V participan en el forward; el backward calcula gradientes para WQ, WK y WV.",
        "inference": "Usa WQ, WK y WV fijos para mezclar contexto mediante atención escalada.",
    },
    "module_4": {
        "training": "Cada cabeza y la proyección WO reciben señal del error global.",
        "inference": "Las cabezas aprendidas atienden en subespacios distintos y WO combina sus resultados.",
    },
    "module_5": {
        "training": "Atención, FFN y parámetros γ/β de LayerNorm reciben gradientes en la capa seleccionada.",
        "inference": "La capa transforma representaciones con pesos fijos y entrega memoria contextual a la siguiente.",
    },
    "module_6": {
        "training": "Teacher forcing procesa posiciones en paralelo con máscara causal y propaga gradiente por las tres subcapas.",
        "inference": "El decoder usa solo el prefijo disponible, consulta al encoder y produce el estado del siguiente token.",
    },
    "module_7": {
        "training": "Cross-entropy compara logits con el objetivo; Top-K y Top-P no intervienen en la pérdida.",
        "inference": "Temperatura, Top-K y Top-P filtran la distribución antes de elegir el siguiente token.",
    },
    "module_8": {
        "training": "El batch recorre el Transformer completo y el error se propaga hacia sus componentes entrenables.",
        "inference": "El encoder crea memoria y el decoder autoregresivo reutiliza el token elegido como nuevo contexto.",
    },
}


def _step(
    identifier: str,
    title: str,
    formula: str,
    explanation: str,
    input_value: str,
    output_value: str,
    visual: str,
    panel_key: str,
    *panel_keys: str,
) -> dict[str, Any]:
    """Contrato único que consumen la lista, la escena y el inspector QML."""
    keys = [key for key in (panel_key, *panel_keys) if key]
    return {
        "id": identifier,
        "title": title,
        "formula": formula,
        "explanation": explanation,
        "input": input_value,
        "output": output_value,
        "visual": visual,
        "panel_key": panel_key,
        "panel_keys": keys,
    }


def _module_steps(module_id: str, mode: str) -> list[dict[str, Any]]:
    """Devuelve un flujo realmente distinto para cada parte del Transformer."""
    training = mode == "training"
    if module_id == "module_1":
        return [
            _step(
                "text",
                "Texto de entrada",
                "texto → segmentos",
                "El tokenizador recibe texto Unicode, no vectores.",
                "Texto escrito",
                "Segmentos candidatos",
                "tokenization_text",
                "token_ids",
            ),
            _step(
                "tokens",
                "Tokenización",
                "texto → [t₀, …, tₙ]",
                "El vocabulario activo decide cómo separar la entrada.",
                "Caracteres o palabras",
                "Tokens ordenados",
                "tokenization",
                "token_ids",
            ),
            _step(
                "ids",
                "Consulta del vocabulario",
                "token → id",
                "Cada token se sustituye por un índice discreto.",
                "Tokens",
                "IDs enteros",
                "token_ids",
                "token_ids",
            ),
            _step(
                "specials",
                "Tokens especiales",
                "[BOS] + ids + [EOS]",
                "BOS abre el objetivo y EOS señala su final cuando corresponde.",
                "IDs de contenido",
                "Secuencia delimitada",
                "special_tokens",
                "decoder_tokens",
            ),
            _step(
                "batch",
                "Batch y padding" if training else "Ajuste de contexto",
                "longitudes → matriz B×T" if training else "ids[:Tmax]",
                "En entrenamiento se alinean longitudes con PAD; en inferencia se recorta el contexto sin inventar contenido.",
                "Secuencias variables",
                "Matriz rectangular",
                "batch_padding",
                "token_ids",
            ),
            _step(
                "mask",
                "Máscara de padding",
                "M = ids ≠ PAD",
                "La atención bloquea las columnas que solo contienen relleno.",
                "IDs del batch",
                "Máscara booleana",
                "padding_mask",
                "padding_mask",
            ),
            _step(
                "no_grad",
                "Participación en el aprendizaje",
                "∂L/∂tokenizador = ∅",
                "Tokenizar, rellenar y enmascarar son operaciones de datos; no aprenden por gradiente.",
                "Batch preparado",
                "Entrada válida del modelo",
                "data_pipeline",
                "padding_mask",
            ),
        ]
    if module_id == "module_2":
        steps = [
            _step(
                "lookup",
                "Consulta de embedding",
                "eᵢ = E[idᵢ]",
                "El ID selecciona una fila aprendida de la tabla E.",
                "Token ID",
                "Vector d_model",
                "embedding_lookup",
                "embedding",
            ),
            _step(
                "scale",
                "Escalamiento",
                "ẽᵢ = eᵢ · √d_model",
                "El escalamiento equilibra la magnitud del embedding y la señal posicional.",
                "Embedding aprendido",
                "Embedding escalado",
                "embedding_scale",
                "embedding_scaled",
            ),
            _step(
                "position",
                "Codificación posicional",
                "PE(pos,2i)=sin(·); PE(pos,2i+1)=cos(·)",
                "Seno y coseno aportan orden sin añadir parámetros entrenables.",
                "Índice de posición",
                "Vector PE fijo",
                "position_encoding",
                "position",
            ),
            _step(
                "sum",
                "Suma de señales",
                "xᵢ = ẽᵢ + PEᵢ",
                "Embedding y posición comparten d_model y se suman dimensión a dimensión.",
                "ẽᵢ y PEᵢ",
                "Representación posicionada",
                "embedding_position_sum",
                "embedding_plus_position",
            ),
            _step(
                "dropout",
                "Dropout" if training else "Salida estable",
                "x̃ = Dropout(x)" if training else "x̃ = x",
                "Durante entrenamiento algunas activaciones se anulan; en inferencia dropout queda desactivado.",
                "Embedding + posición",
                "Entrada del encoder",
                "embedding_dropout",
                "embedding_dropout",
            ),
        ]
        if training:
            steps += [
                _step(
                    "embedding_gradient",
                    "Gradiente de la fila",
                    "g = ∂L/∂E[id]",
                    "Solo las filas consultadas reciben señal directa en este ejemplo.",
                    "Pérdida global",
                    "Gradiente real",
                    "embedding_gradient",
                    "component_gradient",
                ),
                _step(
                    "embedding_update",
                    "Actualización hipotética",
                    "E′ = E − ηg",
                    "Se muestra el cambio que haría SGD, pero no se aplica al modelo compartido.",
                    "E y gradiente",
                    "E′ simulado",
                    "embedding_update",
                    "hypothetical_update",
                ),
            ]
        return steps
    if module_id == "module_3":
        steps = [
            _step(
                "attention_input",
                "Matriz de entrada X",
                "X ∈ ℝᵀˣᵈ",
                "Cada fila representa un token contextualizado.",
                "Embeddings posicionados",
                "X",
                "attention_input",
                "attention_input",
            ),
            _step(
                "weights",
                "Pesos WQ, WK y WV",
                "WQ,WK,WV ∈ ℝᵈˣᵈ",
                "Son parámetros aprendidos; cada cabeza utiliza un bloque de sus columnas de salida.",
                "Parámetros de la capa",
                "Tres proyecciones",
                "attention_qkv_weights",
                "wq",
                "wk",
                "wv",
            ),
            _step(
                "qkv",
                "Proyecciones Q, K y V",
                "Q=XWQ; K=XWK; V=XWV",
                "Queries preguntan, Keys describen compatibilidad y Values transportan contenido.",
                "X y WQ/WK/WV",
                "Q, K y V",
                "attention_qkv",
                "q",
                "k",
                "v",
            ),
            _step(
                "dot",
                "Producto QKᵀ",
                "S₀ = QKᵀ",
                "Cada celda mide compatibilidad entre una query y una key.",
                "Q y K",
                "Scores sin escalar",
                "attention_qk",
                "raw_scores",
            ),
            _step(
                "scale",
                "Escalamiento",
                "S = S₀ / √d_k",
                "Evita que productos grandes saturen softmax.",
                "Scores crudos",
                "Scores escalados",
                "attention_scores",
                "scores",
            ),
            _step(
                "mask",
                "Aplicación de máscara",
                "S′ = mask(S)",
                "Las posiciones no permitidas reciben −∞ antes de softmax.",
                "Scores y máscara",
                "Scores permitidos",
                "attention_mask",
                "masked_scores",
            ),
            _step(
                "softmax",
                "Pesos de atención",
                "A = softmax(S′)",
                "Cada fila se vuelve una distribución que suma aproximadamente uno.",
                "Scores enmascarados",
                "Matriz A",
                "attention_softmax",
                "attention_weights",
            ),
            _step(
                "weighted",
                "Mezcla de Values",
                "C = AV",
                "Los Values se combinan usando los pesos calculados para cada query.",
                "A y V",
                "Contexto por cabeza",
                "attention_weighted",
                "attention_context",
            ),
            _step(
                "output",
                "Salida de atención",
                "Y = Concat(C₁…Cₕ)WO",
                "La proyección final devuelve d_model y entrega el resultado a Add & Norm.",
                "Contextos",
                "Representación atendida",
                "attention_output",
                "attention_output",
            ),
        ]
        if training:
            steps += [
                _step(
                    "backward",
                    "Backward de atención",
                    "∂L/∂WQ, ∂L/∂WK, ∂L/∂WV",
                    "Autograd recorre las mismas multiplicaciones en sentido inverso.",
                    "Pérdida global",
                    "Gradientes reales",
                    "attention_gradient",
                    "component_gradient",
                ),
                _step(
                    "update",
                    "Cambio hipotético",
                    "W′ = W − η∂L/∂W",
                    "El laboratorio calcula el cambio sin modificar los pesos activos.",
                    "Pesos y gradientes",
                    "Parámetros simulados",
                    "attention_update",
                    "hypothetical_update",
                ),
            ]
        return steps
    if module_id == "module_4":
        steps = [
            _step(
                "project",
                "Proyección conjunta",
                "Q,K,V: B×T×d_model",
                "Las proyecciones producen todas las dimensiones de las cabezas.",
                "X",
                "Q/K/V completos",
                "multihead_projection",
                "q",
                "k",
                "v",
            ),
            _step(
                "split",
                "Separación en cabezas",
                "B×T×d → B×h×T×d_head",
                "Un reshape organiza la información en subespacios independientes.",
                "Q/K/V completos",
                "Q/K/V por cabeza",
                "multihead_split",
                "q",
            ),
            _step(
                "maps",
                "Atención independiente",
                "A_h = softmax(Q_hK_hᵀ/√d_head)",
                "Cada cabeza genera su propio mapa sobre los mismos tokens.",
                "Cabeza seleccionada",
                "Mapa T×T",
                "multihead_maps",
                "head_attention",
            ),
            _step(
                "contexts",
                "Contexto por cabeza",
                "C_h = A_hV_h",
                "Cada mapa combina Values dentro de su subespacio.",
                "A_h y V_h",
                "C_h",
                "multihead_context",
                "head_output",
            ),
            _step(
                "concat",
                "Concatenación",
                "C = Concat(C₁,…,Cₕ)",
                "Los subespacios vuelven a formar una representación d_model.",
                "Contextos por cabeza",
                "Vector concatenado",
                "multihead_concat",
                "concatenated",
            ),
            _step(
                "wo",
                "Proyección WO",
                "Y = CWO",
                "WO aprende cómo mezclar la información de todas las cabezas.",
                "C y WO",
                "Salida proyectada",
                "multihead_output",
                "projected",
                "wo",
            ),
        ]
        if training:
            steps += [
                _step(
                    "backward",
                    "Gradientes multi-head",
                    "∂L/∂{WQ,WK,WV,WO}",
                    "La señal de pérdida alcanza tanto a cada cabeza como a su mezcla final.",
                    "Pérdida",
                    "Gradientes reales",
                    "multihead_gradient",
                    "component_gradient",
                ),
                _step(
                    "update",
                    "Actualización hipotética",
                    "θ′ = θ − ηg",
                    "Se visualiza Δθ sin ejecutar el optimizador.",
                    "θ y g",
                    "θ′ simulado",
                    "multihead_update",
                    "hypothetical_update",
                ),
            ]
        return steps
    if module_id == "module_5":
        steps = [
            _step(
                "encoder_input",
                "Entrada de la capa",
                "X_l",
                "La capa seleccionada recibe la salida de la capa anterior.",
                "Representaciones",
                "X_l",
                "encoder_input",
                "encoder_input",
            ),
            _step(
                "encoder_attention",
                "Self-attention",
                "MHA(X_l)",
                "Cada token incorpora información de toda la secuencia visible.",
                "X_l",
                "Actualización contextual",
                "encoder_attention",
                "head_attention",
            ),
            _step(
                "residual_1",
                "Primera conexión residual",
                "R₁ = X_l + MHA(X_l)",
                "El atajo conserva información mientras añade contexto.",
                "X_l y MHA",
                "Suma residual",
                "encoder_residual",
                "attention_update",
            ),
            _step(
                "norm_1",
                "Primera LayerNorm",
                "N₁ = γ(R₁−μ)/√(σ²+ε)+β",
                "Normaliza cada token y aplica γ y β entrenables.",
                "R₁",
                "N₁",
                "encoder_norm",
                "attention_residual",
            ),
            _step(
                "ffn_expand",
                "Expansión FFN",
                "H = N₁W₁+b₁",
                "Cada posición se proyecta de d_model a d_ff de forma independiente.",
                "N₁",
                "Preactivación d_ff",
                "encoder_ffn",
                "ffn_preactivation",
            ),
            _step(
                "ffn_activation",
                "No linealidad",
                "A = φ(H)",
                "La activación permite transformaciones no lineales por token.",
                "H",
                "Activación FFN",
                "encoder_ffn_activation",
                "ffn_hidden",
            ),
            _step(
                "ffn_project",
                "Proyección FFN",
                "F = AW₂+b₂",
                "La red regresa a d_model para poder usar otro residual.",
                "A",
                "F",
                "encoder_ffn_output",
                "ffn_output",
            ),
            _step(
                "norm_2",
                "Segunda Add & Norm",
                "X_{l+1}=LN(N₁+F)",
                "La salida queda lista para la siguiente capa o para el decoder.",
                "N₁ y F",
                "X_{l+1}",
                "encoder_residual_ffn",
                "encoder_output",
            ),
            _step(
                "stack",
                "Pila de encoder",
                "X_N = Encoder_N(…Encoder₁(X₀))",
                "La misma estructura se repite con parámetros distintos en cada capa.",
                "Salida de capa",
                "Memoria del encoder",
                "encoder_layers",
                "encoder_output",
            ),
        ]
        if training:
            steps += [
                _step(
                    "backward",
                    "Backward de la capa",
                    "∂L/∂θ_l",
                    "Atención, FFN, γ y β reciben gradientes del error global.",
                    "Pérdida",
                    "Gradientes de la capa",
                    "encoder_gradient",
                    "component_gradient",
                ),
                _step(
                    "update",
                    "Actualización hipotética",
                    "θ_l′ = θ_l − ηg_l",
                    "El cambio se calcula y se deja sin aplicar.",
                    "θ_l y g_l",
                    "θ_l′ simulado",
                    "encoder_update",
                    "hypothetical_update",
                ),
            ]
        return steps
    if module_id == "module_6":
        prefix_title = "Teacher forcing" if training else "Prefijo autoregresivo"
        prefix_formula = (
            "entrada=[BOS,y₀,…]; objetivo=[y₀,…,EOS]"
            if training
            else "prefijo_t=[BOS,ŷ₀,…,ŷₜ₋₁]"
        )
        steps = [
            _step(
                "decoder_prefix",
                prefix_title,
                prefix_formula,
                "El entrenamiento desplaza el objetivo; la inferencia solo dispone de tokens ya generados.",
                "Objetivo conocido" if training else "Salida parcial",
                "Entrada del decoder",
                "decoder_prefix",
                "decoder_tokens",
            ),
            _step(
                "decoder_embedding",
                "Embedding y posición",
                "Z₀ = E_out[prefijo] + PE",
                "El decoder representa el orden del prefijo antes de atender.",
                "IDs del prefijo",
                "Z₀",
                "decoder_embedding",
                "decoder_input",
            ),
            _step(
                "causal_mask",
                "Máscara causal",
                "M[i,j] = (j ≤ i)",
                "Impide consultar posiciones futuras; desactivarla es una comparación contrafactual, no inferencia válida.",
                "Longitud del prefijo",
                "Triángulo causal",
                "decoder_mask",
                "causal_mask",
            ),
            _step(
                "masked_attention",
                "Masked self-attention",
                "A_self = Attention(Z,Z,Z,M)",
                "Cada posición integra únicamente el prefijo permitido.",
                "Z y M",
                "Contexto causal",
                "decoder_masked_attention",
                "masked_attention",
            ),
            _step(
                "decoder_residual_1",
                "Primera Add & Norm",
                "N₁ = LN(Z + A_self)",
                "El residual preserva el estado previo del decoder.",
                "Z y contexto causal",
                "N₁",
                "decoder_residual",
                "decoder_self_residual",
            ),
            _step(
                "cross_attention",
                "Cross-attention",
                "Q=N₁WQ; K,V=Memoria_encoder·WK/WV",
                "Las queries del decoder consultan la secuencia fuente codificada.",
                "N₁ y memoria",
                "Contexto de fuente",
                "decoder_cross_attention",
                "cross_attention",
            ),
            _step(
                "decoder_residual_2",
                "Segunda Add & Norm",
                "N₂ = LN(N₁ + A_cross)",
                "Integra el contexto recuperado del encoder.",
                "N₁ y cross-attention",
                "N₂",
                "decoder_cross_residual",
                "decoder_cross_residual",
            ),
            _step(
                "decoder_ffn",
                "Feed Forward",
                "F = W₂φ(W₁N₂+b₁)+b₂",
                "Procesa cada posición después de mezclar ambos contextos.",
                "N₂",
                "F",
                "decoder_ffn",
                "decoder_ffn_hidden",
            ),
            _step(
                "decoder_output",
                "Tercera Add & Norm",
                "Z_{l+1}=LN(N₂+F)",
                "Produce la representación que avanza por la pila.",
                "N₂ y F",
                "Salida de la capa",
                "decoder_output",
                "decoder_output",
            ),
            _step(
                "decoder_layers",
                "Pila del decoder",
                "Z_N = Decoder_N(…Decoder₁(Z₀))",
                "Las capas refinan el estado antes de la proyección al vocabulario.",
                "Salida de capa",
                "Estado final",
                "decoder_layers",
                "decoder_output",
            ),
        ]
        if training:
            steps += [
                _step(
                    "backward",
                    "Backward del decoder",
                    "∂L/∂θ_decoder",
                    "La pérdida retrocede por FFN, cross-attention y atención causal.",
                    "Pérdida",
                    "Gradientes reales",
                    "decoder_gradient",
                    "component_gradient",
                ),
                _step(
                    "update",
                    "Actualización hipotética",
                    "θ′ = θ − ηg",
                    "El laboratorio no altera el modelo activo.",
                    "θ y g",
                    "θ′ simulado",
                    "decoder_update",
                    "hypothetical_update",
                ),
            ]
        return steps
    if module_id == "module_7":
        if training:
            return [
                _step(
                    "hidden",
                    "Estado final",
                    "h_t ∈ ℝᵈ",
                    "La representación del decoder resume el contexto disponible en la posición elegida.",
                    "Salida del decoder",
                    "h_t",
                    "output_hidden",
                    "decoder_output",
                ),
                _step(
                    "linear",
                    "Proyección al vocabulario",
                    "z = h_tW_vocabᵀ+b",
                    "Se produce un logit por cada token posible.",
                    "h_t y W_vocab",
                    "Logits",
                    "output_projection",
                    "logits",
                ),
                _step(
                    "target",
                    "Token objetivo",
                    "y_t",
                    "Teacher forcing aporta la respuesta esperada para esta posición.",
                    "Objetivo del batch",
                    "ID correcto",
                    "output_target",
                    "training_targets",
                ),
                _step(
                    "loss",
                    "Cross-entropy",
                    "L_t = −log softmax(z)[y_t]",
                    "La pérdida usa logits crudos; Top-K, Top-P y muestreo no participan.",
                    "Logits y objetivo",
                    "Pérdida real",
                    "output_loss",
                    "loss_per_position",
                ),
                _step(
                    "backward",
                    "Backward",
                    "g = ∂L/∂W_vocab",
                    "Autograd calcula cómo cambiar la proyección para aumentar la probabilidad correcta.",
                    "Pérdida",
                    "Gradiente real",
                    "output_gradient",
                    "component_gradient",
                ),
                _step(
                    "update",
                    "Actualización hipotética",
                    "W′ = W − ηg",
                    "Se enseña el cambio de SGD sin aplicarlo al modelo.",
                    "W_vocab y g",
                    "W′ simulado",
                    "output_update",
                    "hypothetical_update",
                ),
            ]
        return [
            _step(
                "hidden",
                "Estado final",
                "h_t ∈ ℝᵈ",
                "La última posición del decoder alimenta la capa de salida.",
                "Salida del decoder",
                "h_t",
                "output_hidden",
                "decoder_output",
            ),
            _step(
                "linear",
                "Logits del vocabulario",
                "z = h_tW_vocabᵀ+b",
                "Cada token recibe un score sin normalizar.",
                "h_t",
                "Logits",
                "output_projection",
                "logits",
            ),
            _step(
                "temperature",
                "Temperatura",
                "z_T = z / T",
                "T menor concentra la distribución; T mayor la aplana.",
                "Logits",
                "Logits ajustados",
                "output_temperature",
                "temperature_logits",
            ),
            _step(
                "top_k",
                "Filtro Top-K",
                "conservar K mayores",
                "Descarta todo salvo los K logits más altos.",
                "Logits ajustados",
                "K candidatos",
                "output_top_k",
                "top_k_probabilities",
            ),
            _step(
                "top_p",
                "Filtro Top-P",
                "mínimo conjunto con masa ≥ P",
                "Conserva un núcleo dinámico de candidatos ordenados.",
                "Candidatos Top-K",
                "Núcleo Top-P",
                "output_top_p",
                "probabilities",
            ),
            _step(
                "softmax",
                "Probabilidades",
                "p = softmax(z_filtrado)",
                "Los logits supervivientes se normalizan y suman uno.",
                "Logits filtrados",
                "Distribución p",
                "output_softmax",
                "probabilities",
            ),
            _step(
                "select",
                "Selección",
                "ŷ_t = argmax(p)",
                "El laboratorio elige de forma reproducible el candidato más probable.",
                "Distribución p",
                "Siguiente token",
                "output_selection",
                "selected_token",
            ),
            _step(
                "feedback",
                "Realimentación",
                "prefijo ← prefijo ⊕ ŷ_t",
                "El token elegido sería la nueva entrada del decoder en el paso siguiente.",
                "Token elegido",
                "Prefijo ampliado",
                "output_autoregressive",
                "selected_token",
            ),
        ]
    # module_8: integra operaciones sin reutilizar la cuadrícula genérica.
    if training:
        return [
            _step(
                "full_batch",
                "Batch y máscaras",
                "(src,tgt_in,tgt_out,M)",
                "El batch prepara entrada, objetivo desplazado y máscaras.",
                "Texto",
                "Tensores discretos",
                "transformer_tokens",
                "tokens",
                "causal_mask",
            ),
            _step(
                "full_embedding",
                "Embeddings y posición",
                "IDs → E·√d + PE",
                "Ambas ramas pasan al espacio continuo.",
                "IDs",
                "Vectores d_model",
                "transformer_embedding",
                "embedding",
            ),
            _step(
                "full_encoder",
                "Encoder completo",
                "Mem = Encoder(X)",
                "La pila crea memoria contextual de la fuente.",
                "X y máscara",
                "Memoria",
                "transformer_encoder",
                "encoder",
            ),
            _step(
                "full_decoder",
                "Decoder completo",
                "H = Decoder(Y,Mem,M_causal)",
                "Teacher forcing permite evaluar todas las posiciones en paralelo sin revelar el futuro.",
                "Objetivo desplazado y memoria",
                "Estados H",
                "transformer_decoder",
                "decoder",
            ),
            _step(
                "full_logits",
                "Proyección final",
                "Z = HW_vocabᵀ+b",
                "Cada posición produce scores para todo el vocabulario.",
                "H",
                "Logits",
                "transformer_logits",
                "logits",
            ),
            _step(
                "full_loss",
                "Pérdida",
                "L = CE(Z,tgt_out)",
                "Cross-entropy compara predicciones y objetivos válidos.",
                "Logits y objetivo",
                "Escalar L",
                "transformer_loss",
                "loss_per_position",
            ),
            _step(
                "full_backward",
                "Backward",
                "g = ∂L/∂θ",
                "La señal atraviesa salida, decoder, encoder y embeddings.",
                "L",
                "Gradientes",
                "transformer_backward",
                "component_gradient",
            ),
            _step(
                "full_update",
                "Actualización hipotética",
                "θ′ = θ − ηg",
                "Se calcula el cambio representativo sin ejecutar un optimizador.",
                "θ y g",
                "θ′ simulado",
                "transformer_update",
                "hypothetical_update",
            ),
        ]
    return [
        _step(
            "full_tokens",
            "Texto a tokens",
            "texto → IDs",
            "El prompt se transforma en la entrada discreta del modelo.",
            "Texto",
            "IDs",
            "transformer_tokens",
            "tokens",
        ),
        _step(
            "full_embedding",
            "Embeddings y posición",
            "IDs → E·√d + PE",
            "Los IDs se convierten en vectores con orden.",
            "IDs",
            "X",
            "transformer_embedding",
            "embedding",
        ),
        _step(
            "full_encoder",
            "Encoder",
            "Mem = Encoder(X)",
            "La fuente se contextualiza una vez.",
            "X",
            "Memoria",
            "transformer_encoder",
            "encoder",
        ),
        _step(
            "full_decoder",
            "Decoder causal",
            "H_t = Decoder(prefijo,Mem)",
            "El decoder consulta solo el prefijo y la memoria de la fuente.",
            "Prefijo y memoria",
            "Estado h_t",
            "transformer_decoder",
            "decoder",
        ),
        _step(
            "full_logits",
            "Logits",
            "z = h_tW_vocabᵀ+b",
            "La proyección puntúa todo el vocabulario.",
            "h_t",
            "Logits",
            "transformer_logits",
            "logits",
        ),
        _step(
            "full_filters",
            "Temperatura y filtros",
            "z → z/T → Top-K → Top-P",
            "Los controles modifican el conjunto de candidatos.",
            "Logits",
            "Logits filtrados",
            "transformer_softmax",
            "probabilities",
        ),
        _step(
            "full_select",
            "Selección",
            "ŷ_t = argmax softmax(z)",
            "La selección reproducible produce el siguiente token.",
            "Distribución",
            "ŷ_t",
            "transformer_selection",
            "selected_token",
        ),
        _step(
            "full_feedback",
            "Ciclo autoregresivo",
            "prefijo ← prefijo ⊕ ŷ_t",
            "La salida vuelve al decoder para continuar la generación.",
            "ŷ_t",
            "Nuevo prefijo",
            "transformer_autoregressive",
            "selected_token",
        ),
    ]


class ModuleLaboratoryController(QObject):
    """Coordina los ocho laboratorios sin duplicar el motor matemático."""

    resultChanged = Signal()
    modelChanged = Signal()
    analysisCompleted = Signal(str)
    error = Signal(str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._model = None
        self._tokenizer = None
        self._result: dict[str, Any] = {}
        self._full_values: dict[str, list[float | int | bool]] = {}

    def set_model(self, model, tokenizer) -> None:
        self._model = model
        self._tokenizer = tokenizer
        self._result = {}
        self._full_values = {}
        self.modelChanged.emit()
        self.resultChanged.emit()

    def clear_model(self) -> None:
        self._model = None
        self._tokenizer = None
        self._result = {}
        self._full_values = {}
        self.modelChanged.emit()
        self.resultChanged.emit()

    @Property(bool, notify=modelChanged)
    def modelReady(self) -> bool:
        return self._model is not None and self._tokenizer is not None

    @Property("QVariantMap", notify=resultChanged)
    def result(self) -> dict[str, Any]:
        return dict(self._result)

    @staticmethod
    def _shape(tensor: torch.Tensor) -> list[int]:
        return [int(value) for value in tensor.shape]

    @staticmethod
    def _normalized_scalar(value: Any) -> float | int | bool:
        if isinstance(value, bool):
            return value
        if isinstance(value, int):
            return value
        numeric = float(value)
        return round(numeric, 7) if math.isfinite(numeric) else numeric

    @classmethod
    def _matrix_preview(
        cls, tensor: torch.Tensor, rows: int = 12, columns: int = 16
    ) -> list[list[float | int | bool]]:
        value = tensor.detach().cpu()
        while value.dim() > 2 and value.size(0) == 1:
            value = value.squeeze(0)
        if value.dim() == 0:
            value = value.reshape(1, 1)
        elif value.dim() == 1:
            value = value.unsqueeze(0)
        elif value.dim() > 2:
            value = value.reshape(-1, value.size(-1))
        value = value[:rows, :columns]
        return [
            [cls._normalized_scalar(cell) for cell in row] for row in value.tolist()
        ]

    def _panel(
        self,
        key: str,
        title: str,
        description: str,
        tensor: torch.Tensor,
        *,
        color_mode: str = "diverging",
        preview_limit: int = 12,
    ) -> dict[str, Any]:
        detached = tensor.detach().cpu()
        values = detached.reshape(-1).tolist()
        normalized = [self._normalized_scalar(value) for value in values]
        self._full_values[key] = normalized
        numeric = detached.float().reshape(-1)
        finite = numeric[torch.isfinite(numeric)]
        stats = (
            {
                "min": round(float(finite.min().item()), 7),
                "max": round(float(finite.max().item()), 7),
                "mean": round(float(finite.mean().item()), 7),
            }
            if finite.numel()
            else {}
        )
        matrix = self._matrix_preview(detached)
        return {
            "key": key,
            "title": title,
            "description": description,
            "shape": self._shape(detached),
            "matrix": matrix,
            "preview": normalized[:preview_limit],
            "full_length": len(normalized),
            "stats": stats,
            "color_mode": color_mode,
            "matrix_truncated": bool(
                detached.dim() == 0
                or len(matrix)
                < (
                    detached.numel()
                    if detached.dim() <= 1
                    else math.prod(detached.shape[:-1])
                )
                or (
                    matrix
                    and detached.dim() > 0
                    and len(matrix[0]) < detached.shape[-1]
                )
            ),
            "real_data": True,
        }

    @staticmethod
    def _token_text(tokenizer, token_id: int) -> str:
        try:
            text = tokenizer.decode([int(token_id)])
        except Exception:  # noqa: BLE001 - algunos especiales no decodifican
            return f"<{token_id}>"
        return str(text).replace("\n", "↵").replace("\t", "⇥") or "∅"

    @staticmethod
    def _special_ids(tokenizer, config) -> tuple[int, int | None, int | None]:
        pad = config.id_token_relleno
        vocabulary = getattr(tokenizer, "vocab_size", None)
        if callable(vocabulary):
            vocabulary = vocabulary()
        base = int(vocabulary) if isinstance(vocabulary, int) else pad
        bos = (base + 1) if base is not None else (pad + 1 if pad is not None else 0)
        eos = (base + 2) if base is not None else (pad + 2 if pad is not None else None)
        if not 0 <= bos < int(config.tamano_vocabulario):
            bos = (
                pad + 1
                if pad is not None and pad + 1 < config.tamano_vocabulario
                else 0
            )
        if eos is not None and not 0 <= eos < int(config.tamano_vocabulario):
            eos = None
        return int(bos), (int(eos) if eos is not None else None), pad

    @staticmethod
    def _pad_rows(rows: list[list[int]], pad: int, device) -> torch.Tensor:
        width = max(len(row) for row in rows)
        return torch.tensor(
            [row + [pad] * (width - len(row)) for row in rows],
            dtype=torch.long,
            device=device,
        )

    def _prepare_inputs(
        self, module_id: str, text: str, mode: str, selected_token: int
    ) -> dict[str, Any]:
        model = self._model
        tokenizer = self._tokenizer
        config = model.config
        maximum = max(1, min(int(config.longitud_maxima_secuencia), 16))
        source_ids = [
            int(value)
            for value in list(tokenizer.encode(text))[:maximum]
            if 0 <= int(value) < int(config.tamano_vocabulario)
        ]
        if not source_ids:
            raise ValueError("el tokenizador no produjo tokens válidos")
        device = next(model.parameters()).device
        bos, eos, pad = self._special_ids(tokenizer, config)

        source_rows = [source_ids]
        if (
            mode == "training"
            and module_id == "module_1"
            and pad is not None
            and len(source_ids) > 1
        ):
            source_rows.append(source_ids[: max(1, len(source_ids) // 2)])
        source = (
            self._pad_rows(source_rows, int(pad), device)
            if len(source_rows) > 1
            else torch.tensor(source_rows, dtype=torch.long, device=device)
        )

        if mode == "training":
            target_inputs: list[list[int]] = []
            objectives: list[list[int]] = []
            for row in source_rows:
                objective = list(row)
                if eos is not None and len(objective) < maximum:
                    objective.append(eos)
                objective = objective[:maximum]
                decoder_input = ([bos] + objective[:-1])[:maximum]
                target_inputs.append(decoder_input)
                objectives.append(objective)
            target_pad = int(pad) if pad is not None else 0
            target = self._pad_rows(target_inputs, target_pad, device)
            objective = self._pad_rows(objectives, target_pad, device)
        else:
            prefix_count = max(0, min(int(selected_token), len(source_ids)))
            prefix = ([bos] + source_ids[:prefix_count])[:maximum]
            target = torch.tensor([prefix], dtype=torch.long, device=device)
            objective = None

        encoder_mask, _ = model.crear_mascaras(source, target)
        length = target.size(1)
        causal = torch.tril(torch.ones(length, length, dtype=torch.bool, device=device))
        if pad is not None:
            target_visible = target.ne(int(pad))[:, None, None, :]
            causal = causal & target_visible
        return {
            "source_ids": source_ids,
            "source": source,
            "target": target,
            "objective": objective,
            "encoder_mask": encoder_mask,
            "causal_mask": causal,
            "bos": bos,
            "eos": eos,
            "pad": pad,
        }

    @staticmethod
    def _component_parameters(
        model, module_id: str, layer: int
    ) -> list[tuple[str, torch.nn.Parameter]]:
        modules: list[tuple[str, torch.nn.Module]] = []
        if module_id == "module_2":
            modules = [("embedding_entrada", model.embedding_entrada)]
        elif module_id == "module_3":
            attention = model.encoder.bloques[layer].atencion
            modules = [
                ("WQ", attention.proyeccion_q),
                ("WK", attention.proyeccion_k),
                ("WV", attention.proyeccion_v),
            ]
        elif module_id == "module_4":
            modules = [("multi_head", model.encoder.bloques[layer].atencion)]
        elif module_id == "module_5":
            modules = [(f"encoder.{layer}", model.encoder.bloques[layer])]
        elif module_id == "module_6":
            modules = [(f"decoder.{layer}", model.decoder.bloques[layer])]
        elif module_id == "module_7":
            modules = [("capa_salida", model.capa_salida)]
        elif module_id == "module_8":
            modules = [("transformer", model)]

        result: list[tuple[str, torch.nn.Parameter]] = []
        seen: set[int] = set()
        for prefix, module in modules:
            for name, parameter in module.named_parameters():
                if parameter.requires_grad and id(parameter) not in seen:
                    result.append((f"{prefix}.{name}", parameter))
                    seen.add(id(parameter))
        return result

    @staticmethod
    def _representative(tensor: torch.Tensor, selected_row: int = 0) -> torch.Tensor:
        detached = tensor.detach()
        if detached.dim() == 0:
            return detached.reshape(1)
        if detached.dim() == 1:
            return detached[:32]
        if detached.size(0) > 256:
            row = max(0, min(int(selected_row), detached.size(0) - 1))
            return detached[row : row + 1, :32]
        return detached[:12, :32]

    def _training_snapshot(
        self,
        module_id: str,
        loss: torch.Tensor,
        component_parameters: list[tuple[str, torch.nn.Parameter]],
        gradients: tuple[torch.Tensor | None, ...],
        selected_token: int,
    ) -> tuple[dict[str, Any], list[dict[str, Any]]]:
        learning_rate = 1e-3
        summaries: list[dict[str, Any]] = []
        valid: list[tuple[str, torch.nn.Parameter, torch.Tensor]] = []
        squared_total = 0.0
        for (name, parameter), gradient in zip(component_parameters, gradients):
            if gradient is None:
                continue
            detached = gradient.detach()
            norm = float(detached.float().norm().item())
            squared_total += norm * norm
            summaries.append(
                {
                    "name": name,
                    "label": name,
                    "shape": self._shape(parameter),
                    "norm_l2": round(norm, 9),
                    "mean_abs": round(float(detached.float().abs().mean().item()), 9),
                    "max_abs": round(float(detached.float().abs().max().item()), 9),
                    "hypothetical_update_norm": round(learning_rate * norm, 9),
                }
            )
            valid.append((name, parameter, detached))
        gradient_norm = math.sqrt(squared_total)
        panels: list[dict[str, Any]] = []
        representative_name = ""
        if valid:
            representative_name, parameter, gradient = max(
                valid, key=lambda item: float(item[2].float().norm().item())
            )
            before = self._representative(parameter, selected_token)
            grad_slice = self._representative(gradient, selected_token)
            after = before - learning_rate * grad_slice
            panels.extend(
                [
                    self._panel(
                        "parameter_before",
                        "Parámetro actual",
                        f"Ventana real de {representative_name}.",
                        before,
                    ),
                    self._panel(
                        "component_gradient",
                        "Gradiente del componente",
                        f"∂L/∂θ para {representative_name}.",
                        grad_slice,
                    ),
                    self._panel(
                        "hypothetical_update",
                        "Parámetro después de SGD (simulado)",
                        "θ − ηg; este valor no se escribe en el modelo.",
                        after,
                    ),
                ]
            )
        snapshot = {
            "loss": round(float(loss.detach().item()), 8),
            "trainable": bool(component_parameters),
            "gradients": summaries,
            "gradient_norm": round(gradient_norm, 9),
            "update_norm": round(learning_rate * gradient_norm, 9),
            "hypothetical_learning_rate": learning_rate,
            "update_applied": False,
            "representative_parameter": representative_name,
            "note": "Gradientes reales; actualización hipotética no aplicada al modelo.",
        }
        return snapshot, panels

    @staticmethod
    def _attention_calculation(block, head: int) -> dict[str, torch.Tensor]:
        trace = block.conexion_atencion.ultima_traza or {}
        x = trace.get("entrada_visual")
        if x is None:
            return {}
        attention = block.atencion
        with torch.no_grad():
            q_all = attention._separar_cabezas(attention.proyeccion_q(x))
            k_all = attention._separar_cabezas(attention.proyeccion_k(x))
            v_all = attention._separar_cabezas(attention.proyeccion_v(x))
            raw_all = q_all @ k_all.transpose(-2, -1)
            scaled_all = raw_all / math.sqrt(attention.dimension_cabeza)
            weights_all = attention.ultimos_pesos_atencion
            contexts_all = weights_all @ v_all
            concatenated = attention._combinar_cabezas(contexts_all)
            projected = attention.proyeccion_salida(concatenated)
        return {
            "x": x[0],
            "q_all": q_all[0],
            "k_all": k_all[0],
            "v_all": v_all[0],
            "raw_scores_all": raw_all[0],
            "scores_all": scaled_all[0],
            "weights_all": weights_all[0],
            "q": q_all[0, head],
            "k": k_all[0, head],
            "v": v_all[0, head],
            "raw_scores": raw_all[0, head],
            "scores": scaled_all[0, head],
            "weights": weights_all[0, head],
            "context": contexts_all[0, head],
            "contexts_all": contexts_all[0],
            "concatenated": concatenated[0],
            "projected": projected[0],
        }

    @staticmethod
    def _rounded_matrix(tensor: torch.Tensor) -> list[list[float]]:
        return [
            [round(float(value), 6) for value in row]
            for row in tensor.detach().float().cpu().tolist()
        ]

    def _focus_encoder_attention(
        self,
        forward_detail: dict[str, Any],
        layer: int,
        selected_token: int,
    ) -> None:
        """Hace que la escena explique la query elegida, no siempre la última."""
        layers = forward_detail.get("encoder") or []
        if not 0 <= layer < len(layers):
            return
        calculation = self._attention_calculation(self._model.encoder.bloques[layer], 0)
        if not calculation:
            return
        query = max(0, min(selected_token, calculation["q_all"].size(1) - 1))
        weights = calculation["weights_all"][:, query, :]
        highlighted_key = int(weights.mean(dim=0).argmax().item())
        contributions = (weights.unsqueeze(-1) * calculation["v_all"]).norm(dim=-1)
        attention = dict(layers[layer].get("atencion") or {})
        attention.update(
            {
                "q": self._rounded_matrix(calculation["q_all"][:, query, :]),
                "k": self._rounded_matrix(calculation["k_all"][:, highlighted_key, :]),
                "v": self._rounded_matrix(calculation["v_all"][:, highlighted_key, :]),
                "scores": self._rounded_matrix(calculation["scores_all"][:, query, :]),
                "scores_enmascarados": self._rounded_matrix(
                    calculation["scores_all"][:, query, :]
                ),
                "mascara": [
                    [1 for _ in range(weights.size(1))] for _ in range(weights.size(0))
                ],
                "atencion": self._rounded_matrix(weights),
                "contribuciones": self._rounded_matrix(contributions),
                "salida_cabezas": self._rounded_matrix(
                    calculation["contexts_all"][:, query, :]
                ),
                "salida_concatenada": [
                    round(float(value), 6)
                    for value in calculation["concatenated"][query]
                    .detach()
                    .float()
                    .cpu()
                    .tolist()
                ],
                "salida_proyectada": [
                    round(float(value), 6)
                    for value in calculation["projected"][query]
                    .detach()
                    .float()
                    .cpu()
                    .tolist()
                ],
                "key_destacada": highlighted_key,
                "query_seleccionada": query,
                "aggregation_method": "ninguna; query seleccionada por el usuario",
            }
        )
        layers[layer]["atencion"] = attention

    def _candidate_data(
        self,
        raw_logits: torch.Tensor,
        mode: str,
        temperature: float,
        top_k: int,
        top_p: float,
    ) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor, list[dict[str, Any]], int]:
        if mode == "inference":
            adjusted = aplicar_temperatura(raw_logits, max(0.01, float(temperature)))
            after_k = filtrar_top_k(
                adjusted, max(1, min(int(top_k), adjusted.size(-1)))
            )
            filtered = filtrar_top_p(after_k, max(0.01, min(float(top_p), 1.0)))
        else:
            adjusted = raw_logits
            after_k = raw_logits
            filtered = raw_logits
        probabilities = F.softmax(filtered, dim=-1)
        selected_id = int(torch.argmax(probabilities[0]).item())
        count = min(10, probabilities.size(-1))
        top_values, top_ids = torch.topk(probabilities[0], count)
        candidates = []
        for rank, (probability, token_id) in enumerate(
            zip(top_values.tolist(), top_ids.tolist()), start=1
        ):
            token_id = int(token_id)
            candidates.append(
                {
                    "id": token_id,
                    "token_id": token_id,
                    "text": self._token_text(self._tokenizer, token_id),
                    "texto": self._token_text(self._tokenizer, token_id),
                    "probability": round(float(probability), 7),
                    "probabilidad": round(float(probability), 7),
                    "logit": round(float(raw_logits[0, token_id].item()), 7),
                    "rank": rank,
                    "rango": rank,
                    "chosen": token_id == selected_id,
                    "elegido": token_id == selected_id,
                }
            )
        return adjusted, after_k, probabilities, candidates, selected_id

    def _base_panels(
        self,
        module_id: str,
        prepared: dict[str, Any],
        trace: dict[str, Any],
        logits: torch.Tensor,
        loss: torch.Tensor | None,
        layer: int,
        head: int,
        selected_token: int,
        adjusted_logits: torch.Tensor,
        top_k_probabilities: torch.Tensor,
        probabilities: torch.Tensor,
        selected_id: int,
    ) -> list[dict[str, Any]]:
        model = self._model
        source = prepared["source"]
        target = prepared["target"]
        pad = prepared["pad"]
        source_index = max(0, min(selected_token, source.size(1) - 1))
        encoder_block = model.encoder.bloques[layer]
        decoder_block = model.decoder.bloques[layer]
        attention = self._attention_calculation(encoder_block, head)
        panels: list[dict[str, Any]] = []

        if module_id == "module_1":
            visible = (
                source.ne(int(pad))
                if pad is not None
                else torch.ones_like(source, dtype=torch.bool)
            )
            positions = torch.arange(source.size(1), device=source.device).repeat(
                source.size(0), 1
            )
            batch_description = (
                "La primera fila usa la tokenización real. La segunda es una "
                "versión truncada del mismo texto, marcada como ejemplo didáctico, "
                "para hacer visible el padding."
                if source.size(0) > 1
                else "IDs reales producidos por el tokenizador activo."
            )
            panels.extend(
                [
                    self._panel(
                        "token_ids",
                        "Token IDs / batch",
                        batch_description,
                        source,
                        color_mode="sequential",
                    ),
                    self._panel(
                        "positions",
                        "Posiciones",
                        "Índice explícito de cada columna de la secuencia.",
                        positions,
                        color_mode="sequential",
                    ),
                    self._panel(
                        "decoder_tokens",
                        "Secuencia desplazada",
                        "Entrada real que recibe el decoder en este experimento.",
                        target,
                        color_mode="sequential",
                    ),
                    self._panel(
                        "padding_mask",
                        "Máscara de padding",
                        "True conserva una key; False bloquea una posición PAD.",
                        visible,
                        color_mode="mask",
                    ),
                ]
            )
            return panels

        if module_id == "module_2":
            panels.extend(
                [
                    self._panel(
                        "embedding",
                        "Embedding seleccionado",
                        "Fila aprendida E[id] del token elegido.",
                        trace["embedding_encoder"][0, source_index],
                    ),
                    self._panel(
                        "embedding_scaled",
                        "Embedding escalado",
                        "E[id] multiplicado por √d_model.",
                        trace["embedding_encoder_escalado"][0, source_index],
                    ),
                    self._panel(
                        "position",
                        "Codificación posicional",
                        "Vector sinusoidal fijo de la posición elegida.",
                        trace["posicion_encoder"][0, source_index],
                    ),
                    self._panel(
                        "embedding_plus_position",
                        "Embedding + posición",
                        "Suma que entra a la rama encoder antes de dropout.",
                        trace["entrada_encoder"][0, source_index],
                    ),
                    self._panel(
                        "embedding_dropout",
                        "Salida de dropout",
                        "Activación realmente entregada al encoder.",
                        trace["entrada_encoder_dropout"][0, source_index],
                    ),
                ]
            )
            return panels

        if module_id in {"module_3", "module_4"}:
            attn_module = encoder_block.atencion
            d_head = int(model.config.dimension_cabeza)
            start = head * d_head
            end = start + d_head
            panels.extend(
                [
                    self._panel(
                        "attention_input",
                        "Entrada X",
                        "Matriz real recibida por self-attention en la capa elegida.",
                        attention["x"],
                    ),
                    self._panel(
                        "wq",
                        "WQ de la cabeza",
                        "Filas de salida de la proyección Query para la cabeza elegida.",
                        attn_module.proyeccion_q.weight[start:end],
                    ),
                    self._panel(
                        "wk",
                        "WK de la cabeza",
                        "Filas de salida de la proyección Key para la cabeza elegida.",
                        attn_module.proyeccion_k.weight[start:end],
                    ),
                    self._panel(
                        "wv",
                        "WV de la cabeza",
                        "Filas de salida de la proyección Value para la cabeza elegida.",
                        attn_module.proyeccion_v.weight[start:end],
                    ),
                    self._panel(
                        "q",
                        "Queries Q",
                        "X proyectada al subespacio Query de la cabeza.",
                        attention["q"],
                    ),
                    self._panel(
                        "k",
                        "Keys K",
                        "X proyectada al subespacio Key de la cabeza.",
                        attention["k"],
                    ),
                    self._panel(
                        "v",
                        "Values V",
                        "X proyectada al subespacio Value de la cabeza.",
                        attention["v"],
                    ),
                    self._panel(
                        "raw_scores",
                        "Producto QKᵀ",
                        "Compatibilidades antes de dividir por √d_k.",
                        attention["raw_scores"],
                    ),
                    self._panel(
                        "scores",
                        "Scores QKᵀ/√d_k",
                        "Compatibilidades escaladas.",
                        attention["scores"],
                    ),
                    self._panel(
                        "masked_scores",
                        "Scores permitidos",
                        "En el encoder solo se bloquea padding cuando existe.",
                        attention["scores"],
                    ),
                    self._panel(
                        "attention_weights",
                        "Pesos softmax",
                        "Distribución de atención real de la cabeza seleccionada.",
                        attention["weights"],
                        color_mode="sequential",
                    ),
                    self._panel(
                        "attention_context",
                        "Contexto AV",
                        "Mezcla de Values para todas las queries de la cabeza.",
                        attention["context"],
                    ),
                    self._panel(
                        "attention_output",
                        "Salida proyectada",
                        "Resultado multi-head que se entrega a Add & Norm.",
                        attention["projected"],
                    ),
                    self._panel(
                        "head_attention",
                        f"Mapa de cabeza {head + 1}",
                        "Atención independiente de la cabeza seleccionada.",
                        attention["weights"],
                        color_mode="sequential",
                    ),
                    self._panel(
                        "head_output",
                        "Salida de la cabeza",
                        "Contexto completo producido por esta cabeza.",
                        attention["context"],
                    ),
                    self._panel(
                        "concatenated",
                        "Cabezas concatenadas",
                        "Contextos de todas las cabezas unidos en d_model.",
                        attention["concatenated"],
                    ),
                    self._panel(
                        "wo",
                        "Matriz WO",
                        "Proyección que mezcla las cabezas concatenadas.",
                        attn_module.proyeccion_salida.weight,
                    ),
                    self._panel(
                        "projected",
                        "Salida después de WO",
                        "Representación final de Multi-Head Attention.",
                        attention["projected"],
                    ),
                ]
            )
            return panels

        if module_id == "module_5":
            residual_attention = encoder_block.conexion_atencion.ultima_traza or {}
            ffn = encoder_block.feed_forward.ultima_traza or {}
            residual_ffn = encoder_block.conexion_feed_forward.ultima_traza or {}
            visual_token = max(
                0,
                min(source_index, residual_attention["entrada_visual"].size(1) - 1),
            )
            panels.extend(
                [
                    self._panel(
                        "encoder_input",
                        "Entrada del token elegido",
                        "Vector real antes de self-attention en la capa seleccionada.",
                        residual_attention["entrada_visual"][0, visual_token],
                    ),
                    self._panel(
                        "head_attention",
                        f"Atención de H{head + 1}",
                        "Mapa real dentro de la capa elegida.",
                        encoder_block.ultimos_pesos_atencion[0, head],
                        color_mode="sequential",
                    ),
                    self._panel(
                        "attention_update",
                        "Actualización de atención",
                        "Valor del token elegido añadido por la rama residual.",
                        residual_attention["actualizacion_visual"][0, visual_token],
                    ),
                    self._panel(
                        "attention_residual",
                        "Primera Add & Norm",
                        "Salida normalizada del token elegido tras self-attention.",
                        residual_attention["salida_visual"][0, visual_token],
                    ),
                    self._panel(
                        "ffn_preactivation",
                        "Preactivación FFN",
                        "Expansión W₁ del token elegido.",
                        ffn["preactivacion_visual"][0, visual_token],
                    ),
                    self._panel(
                        "ffn_hidden",
                        "Activación FFN",
                        f"Valores del token elegido después de {ffn['activacion_nombre']}.",
                        ffn["activacion_visual"][0, visual_token],
                    ),
                    self._panel(
                        "ffn_output",
                        "Proyección W₂",
                        "Token elegido proyectado de vuelta a d_model.",
                        ffn["salida_visual"][0, visual_token],
                    ),
                    self._panel(
                        "encoder_output",
                        "Salida de la capa",
                        "Segunda Add & Norm del token elegido.",
                        residual_ffn["salida_visual"][0, visual_token],
                    ),
                ]
            )
            return panels

        if module_id == "module_6":
            self_weights = decoder_block.ultimos_pesos_autoatencion[0, head]
            cross_weights = decoder_block.ultimos_pesos_atencion_cruzada[0, head]
            self_residual = decoder_block.conexion_autoatencion.ultima_traza or {}
            cross_residual = decoder_block.conexion_atencion_cruzada.ultima_traza or {}
            ffn = decoder_block.feed_forward.ultima_traza or {}
            output_residual = decoder_block.conexion_feed_forward.ultima_traza or {}
            causal = prepared["selected_causal_mask"]
            visual_token = max(
                0,
                min(selected_token, self_residual["salida_visual"].size(1) - 1),
            )
            panels.extend(
                [
                    self._panel(
                        "decoder_tokens",
                        "Prefijo / objetivo desplazado",
                        "IDs que entran realmente al decoder.",
                        target,
                        color_mode="sequential",
                    ),
                    self._panel(
                        "decoder_input",
                        "Embedding + posición del decoder",
                        "Representación continua antes de las capas.",
                        trace["entrada_decoder"],
                    ),
                    self._panel(
                        "causal_mask",
                        "Máscara usada",
                        "Triangular en el cálculo válido o totalmente visible en la comparación contrafactual.",
                        causal,
                        color_mode="mask",
                    ),
                    self._panel(
                        "masked_attention",
                        "Self-attention causal",
                        "Mapa real de la cabeza seleccionada.",
                        self_weights,
                        color_mode="sequential",
                    ),
                    self._panel(
                        "decoder_self_residual",
                        "Primera Add & Norm",
                        "Salida del token elegido tras atención causal.",
                        self_residual["salida_visual"][0, visual_token],
                    ),
                    self._panel(
                        "cross_attention",
                        "Cross-attention",
                        "Queries del decoder sobre keys de la fuente.",
                        cross_weights,
                        color_mode="sequential",
                    ),
                    self._panel(
                        "decoder_cross_residual",
                        "Segunda Add & Norm",
                        "Token elegido tras integrar la memoria del encoder.",
                        cross_residual["salida_visual"][0, visual_token],
                    ),
                    self._panel(
                        "decoder_ffn_hidden",
                        "Activación FFN",
                        "Espacio d_ff del token elegido.",
                        ffn["activacion_visual"][0, visual_token],
                    ),
                    self._panel(
                        "decoder_output",
                        "Salida del decoder",
                        "Tercera Add & Norm del token elegido en la capa seleccionada.",
                        output_residual["salida_visual"][0, visual_token],
                    ),
                ]
            )
            return panels

        output_position = max(0, min(selected_token, logits.size(1) - 1))
        raw = logits[0:1, output_position, :]
        if module_id == "module_7":
            hidden = trace["salida_decoder"][0, output_position]
            panels.extend(
                [
                    self._panel(
                        "decoder_output",
                        "Estado final h",
                        "Vector del decoder que alimenta Linear.",
                        hidden,
                    ),
                    self._panel(
                        "logits",
                        "Logits reales",
                        "Salida lineal completa antes de filtros.",
                        raw,
                    ),
                    self._panel(
                        "temperature_logits",
                        "Logits con temperatura",
                        "z/T en modo inferencia; z sin cambios al entrenar.",
                        adjusted_logits,
                    ),
                    self._panel(
                        "top_k_probabilities",
                        "Candidatos tras Top-K",
                        "Distribución normalizada conservando únicamente los K logits mayores.",
                        top_k_probabilities,
                        color_mode="sequential",
                    ),
                    self._panel(
                        "probabilities",
                        "Distribución final",
                        "Softmax de los logits válidos.",
                        probabilities,
                        color_mode="sequential",
                    ),
                    self._panel(
                        "selected_token",
                        "Token seleccionado",
                        "ID elegido por la distribución mostrada.",
                        torch.tensor([selected_id], device=raw.device),
                        color_mode="sequential",
                    ),
                ]
            )
            if loss is not None and prepared["objective"] is not None:
                objective = prepared["objective"]
                ignore = int(pad) if pad is not None else -100
                per_position = F.cross_entropy(
                    logits.transpose(1, 2),
                    objective,
                    reduction="none",
                    ignore_index=ignore,
                )
                panels.extend(
                    [
                        self._panel(
                            "training_targets",
                            "Tokens objetivo",
                            "Respuesta esperada por posición.",
                            objective,
                            color_mode="sequential",
                        ),
                        self._panel(
                            "loss_per_position",
                            "Pérdida por posición",
                            "Cross-entropy antes del promedio.",
                            per_position,
                            color_mode="sequential",
                        ),
                    ]
                )
            return panels

        # Módulo 8: hitos del recorrido completo.
        panels.extend(
            [
                self._panel(
                    "tokens",
                    "Token IDs",
                    "Inicio discreto de la traza completa.",
                    source,
                    color_mode="sequential",
                ),
                self._panel(
                    "embedding",
                    "Embeddings + posición",
                    "Entrada continua del encoder.",
                    trace["entrada_encoder"],
                ),
                self._panel(
                    "encoder",
                    "Memoria del encoder",
                    "Fuente contextualizada después de todas las capas.",
                    trace["salida_encoder"],
                ),
                self._panel(
                    "causal_mask",
                    "Máscara causal",
                    "Regla de visibilidad del decoder.",
                    prepared["selected_causal_mask"],
                    color_mode="mask",
                ),
                self._panel(
                    "decoder",
                    "Estados del decoder",
                    "Prefijo integrado con la memoria del encoder.",
                    trace["salida_decoder"],
                ),
                self._panel(
                    "logits",
                    "Logits del vocabulario",
                    "Un score real por token posible.",
                    raw,
                ),
                self._panel(
                    "probabilities",
                    "Distribución final",
                    "Probabilidades después de los controles de inferencia.",
                    probabilities,
                    color_mode="sequential",
                ),
                self._panel(
                    "selected_token",
                    "Token elegido",
                    "Salida que se realimentaría al decoder.",
                    torch.tensor([selected_id], device=raw.device),
                    color_mode="sequential",
                ),
            ]
        )
        if loss is not None and prepared["objective"] is not None:
            ignore = int(pad) if pad is not None else -100
            per_position = F.cross_entropy(
                logits.transpose(1, 2),
                prepared["objective"],
                reduction="none",
                ignore_index=ignore,
            )
            panels.append(
                self._panel(
                    "loss_per_position",
                    "Pérdida por posición",
                    "Contribución válida de cada objetivo.",
                    per_position,
                    color_mode="sequential",
                )
            )
        return panels

    @Slot(str, str, int, float, int, float, bool)
    def analyze(
        self,
        module_id: str,
        text: str,
        head_index: int,
        temperature: float,
        top_k: int,
        top_p: float,
        causal_mask: bool,
    ) -> None:
        """Compatibilidad con la vista anterior; conserva sus paneles públicos."""
        self._dispatch(
            module_id,
            text,
            "inference",
            0,
            head_index,
            1_000_000,
            temperature,
            top_k,
            top_p,
            causal_mask,
            legacy=True,
        )

    @Slot(str, str, str, int, int, int, float, int, float, bool)
    def explore(
        self,
        module_id: str,
        text: str,
        mode: str,
        layer_index: int,
        head_index: int,
        token_index: int,
        temperature: float,
        top_k: int,
        top_p: float,
        causal_mask: bool,
    ) -> None:
        """Ejecuta el laboratorio especializado en entrenamiento o inferencia."""
        self._dispatch(
            module_id,
            text,
            mode,
            layer_index,
            head_index,
            token_index,
            temperature,
            top_k,
            top_p,
            causal_mask,
            legacy=False,
        )

    def _dispatch(
        self,
        module_id: str,
        text: str,
        mode: str,
        layer_index: int,
        head_index: int,
        token_index: int,
        temperature: float,
        top_k: int,
        top_p: float,
        causal_mask: bool,
        *,
        legacy: bool,
    ) -> None:
        if not self.modelReady:
            self.error.emit(
                "Selecciona o crea un modelo antes de abrir este laboratorio."
            )
            return
        owner = self.parent()
        training_controller = getattr(owner, "_training_controller", None)
        if (
            training_controller is not None
            and training_controller.esta_entrenando
            and not training_controller.esta_pausado
        ):
            self.error.emit(
                "Pausa el entrenamiento activo antes de ejecutar el laboratorio; "
                "ambos usan el mismo modelo."
            )
            return
        inference_controller = getattr(owner, "_inference_controller", None)
        if (
            inference_controller is not None
            and inference_controller.esta_generando
            and not inference_controller.esta_pausado
        ):
            self.error.emit(
                "Pausa la generación activa antes de ejecutar el laboratorio; "
                "ambos usan el mismo modelo."
            )
            return
        source_text = str(text).strip()
        if not source_text:
            self.error.emit("Escribe un texto de entrada.")
            return
        normalized_module = str(module_id)
        if normalized_module not in _LEGACY_PANEL_KEYS:
            self.error.emit(
                "El módulo solicitado no tiene un laboratorio especializado."
            )
            return
        normalized_mode = str(mode).lower()
        if normalized_mode not in {"training", "inference"}:
            normalized_mode = "inference"
        try:
            self._explore(
                normalized_module,
                source_text,
                normalized_mode,
                int(layer_index),
                int(head_index),
                int(token_index),
                float(temperature),
                int(top_k),
                float(top_p),
                bool(causal_mask),
                legacy=legacy,
            )
        except Exception as exc:  # noqa: BLE001 - el mensaje se muestra en QML
            self.error.emit(f"No se pudo analizar el modelo: {exc}")

    def _explore(
        self,
        module_id: str,
        text: str,
        mode: str,
        layer_index: int,
        head_index: int,
        token_index: int,
        temperature: float,
        top_k: int,
        top_p: float,
        causal_mask: bool,
        *,
        legacy: bool,
    ) -> None:
        model = self._model
        tokenizer = self._tokenizer
        config = model.config
        layer = max(0, min(layer_index, int(config.num_capas) - 1))
        head = max(0, min(head_index, int(config.num_cabezas) - 1))
        prepared = self._prepare_inputs(module_id, text, mode, token_index)
        source = prepared["source"]
        target = prepared["target"]
        objective = prepared["objective"]
        selected_token = max(0, min(token_index, source.size(1) - 1))

        selected_causal = prepared["causal_mask"]
        if not causal_mask:
            length = target.size(1)
            selected_causal = torch.ones(
                length, length, dtype=torch.bool, device=target.device
            )
            if prepared["pad"] is not None:
                selected_causal = (
                    selected_causal & target.ne(int(prepared["pad"]))[:, None, None, :]
                )
        prepared["selected_causal_mask"] = selected_causal

        was_training = bool(model.training)
        previous_capture = bool(model.capturar_traza_entrenamiento)
        loss: torch.Tensor | None = None
        gradients: tuple[torch.Tensor | None, ...] = ()
        component_parameters: list[tuple[str, torch.nn.Parameter]] = []
        try:
            model.train(mode == "training")
            model.capturar_traza_entrenamiento = True
            if mode == "training":
                logits = model(
                    source,
                    target,
                    mascara_encoder=prepared["encoder_mask"],
                    mascara_causal=selected_causal,
                )
                if objective is None:
                    raise RuntimeError("falta el objetivo de entrenamiento")
                loss = model.calcular_perdida(logits, objective)
                component_parameters = self._component_parameters(
                    model, module_id, layer
                )
                if component_parameters:
                    gradients = torch.autograd.grad(
                        loss,
                        [parameter for _, parameter in component_parameters],
                        allow_unused=True,
                    )
            else:
                with torch.no_grad():
                    logits = model(
                        source,
                        target,
                        mascara_encoder=prepared["encoder_mask"],
                        mascara_causal=selected_causal,
                    )
            trace = dict(model.ultima_traza or {})
        finally:
            model.capturar_traza_entrenamiento = previous_capture
            model.train(was_training)

        output_position = (
            max(0, min(selected_token, logits.size(1) - 1))
            if mode == "training"
            else logits.size(1) - 1
        )
        raw_logits = logits[0:1, output_position, :].detach()
        adjusted, after_k, probabilities, candidates, selected_id = (
            self._candidate_data(raw_logits, mode, temperature, top_k, top_p)
        )
        top_k_probabilities = F.softmax(after_k, dim=-1)

        self._full_values = {}
        panels = self._base_panels(
            module_id,
            prepared,
            trace,
            logits.detach(),
            loss,
            layer,
            head,
            selected_token,
            adjusted.detach(),
            top_k_probabilities.detach(),
            probabilities.detach(),
            selected_id,
        )

        training_snapshot: dict[str, Any] = {
            "trainable": module_id != "module_1",
            "gradients": [],
            "update_applied": False,
        }
        if mode == "training" and loss is not None:
            training_snapshot, training_panels = self._training_snapshot(
                module_id,
                loss,
                component_parameters,
                gradients,
                selected_token,
            )
            panels.extend(training_panels)

        inference_snapshot: dict[str, Any] = {}
        if mode == "inference":
            generated_prefix = [
                int(value)
                for value in target[0, 1:].detach().cpu().tolist()
                if prepared["pad"] is None or int(value) != int(prepared["pad"])
            ]
            step_data = {
                "paso": 0,
                "token_id": selected_id,
                "logits": raw_logits,
                "logits_lineales": raw_logits,
                "traza_global": trace,
                "pesos_atencion_encoder_por_capa": model.encoder.pesos_atencion_por_capa(),
                "pesos_autoatencion_por_capa": model.decoder.pesos_autoatencion_por_capa(),
                "pesos_atencion_cruzada_por_capa": model.decoder.pesos_atencion_cruzada_por_capa(),
            }
            inference_snapshot = resumir_paso_inferencia(
                model,
                tokenizer,
                source[0:1],
                step_data,
                [*generated_prefix, selected_id],
                prepared["bos"],
                temperature,
                max(1, min(top_k, int(config.tamano_vocabulario))),
                max(0.01, min(top_p, 1.0)),
                False,
                incluir_detalle_forward=True,
            )
            inference_snapshot["modo_muestreo"] = "Selección reproducible"
            forward_detail = inference_snapshot.pop("detalle_forward", {})
        else:
            forward_detail = construir_detalle_forward(
                model, trace, raw_logits, raw_logits
            )
        if module_id in {"module_3", "module_4", "module_5", "module_8"}:
            self._focus_encoder_attention(forward_detail, layer, selected_token)

        tokens = [
            {
                "position": index,
                "id": int(token_id),
                "text": self._token_text(tokenizer, token_id),
            }
            for index, token_id in enumerate(prepared["source_ids"])
        ]
        if legacy:
            allowed = set(_LEGACY_PANEL_KEYS[module_id])
            panels = [panel for panel in panels if panel["key"] in allowed]

        self._result = {
            "module_id": module_id,
            "mode": mode,
            "specialization": {
                "module_1": "tokenization",
                "module_2": "embedding",
                "module_3": "attention",
                "module_4": "multi_head",
                "module_5": "encoder",
                "module_6": "decoder",
                "module_7": "output",
                "module_8": "transformer",
            }[module_id],
            "source": "real_model",
            "real_data": True,
            "tokens": tokens,
            "panels": panels,
            "steps": _module_steps(module_id, mode),
            "selected_layer": layer,
            "selected_head": head,
            "selected_token_index": selected_token,
            "selected_token": {
                "id": selected_id,
                "text": self._token_text(tokenizer, selected_id),
            },
            "candidates": candidates,
            "training": training_snapshot,
            "inference_snapshot": inference_snapshot,
            "forward_detail": forward_detail,
            "behavior": _BEHAVIOR[module_id],
            "experiment": {
                "causal_mask": bool(causal_mask),
                "causal_counterfactual": not bool(causal_mask),
                "temperature": round(max(0.01, temperature), 4),
                "top_k": max(1, min(top_k, int(config.tamano_vocabulario))),
                "top_p": round(max(0.01, min(top_p, 1.0)), 4),
                "weights_modified": False,
                "didactic_example": mode == "training",
                "didactic_note": (
                    "La segunda secuencia se deriva truncando la entrada para "
                    "demostrar padding; no se presenta como un dato del dataset."
                    if module_id == "module_1" and source.size(0) > 1
                    else (
                        "El objetivo didáctico reutiliza los tokens escritos y EOS; "
                        "el forward, la pérdida y los gradientes sí son cálculos reales."
                        if mode == "training"
                        else ""
                    )
                ),
            },
            "model_dimensions": {
                "d_model": int(config.dimension_modelo),
                "heads": int(config.num_cabezas),
                "d_head": int(config.dimension_cabeza),
                "d_ff": int(config.dimension_ff),
                "layers": int(config.num_capas),
                "vocabulary": int(config.tamano_vocabulario),
            },
        }
        self.resultChanged.emit()
        self.analysisCompleted.emit(module_id)

    @Slot(str, int, int, result="QVariantList")
    def fullValues(self, key: str, offset: int, limit: int) -> list[Any]:
        values = self._full_values.get(str(key), [])
        start = max(0, int(offset))
        count = max(1, min(int(limit), 512))
        return list(values[start : start + count])

    @Slot(str, result=int)
    def fullValueLength(self, key: str) -> int:
        return len(self._full_values.get(str(key), []))
