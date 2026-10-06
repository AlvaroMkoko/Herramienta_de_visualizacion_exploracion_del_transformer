"""Laboratorios modulares alimentados por un forward real del modelo activo."""

from __future__ import annotations

import math
from typing import Any

from PySide6.QtCore import Property, QObject, Signal, Slot
import torch
import torch.nn.functional as F

from model.motor_llm.muestreo import aplicar_temperatura, filtrar_top_k, filtrar_top_p


class ModuleLaboratoryController(QObject):
    """Produce snapshots acotados para QML y conserva los valores completos paginados."""

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

    def _panel(
        self,
        key: str,
        title: str,
        description: str,
        tensor: torch.Tensor,
        row: int = 0,
        preview_limit: int = 12,
    ) -> dict[str, Any]:
        values = tensor.detach().cpu().reshape(-1).tolist()
        normalized: list[float | int | bool] = []
        for value in values:
            if isinstance(value, bool):
                normalized.append(value)
            elif isinstance(value, int):
                normalized.append(value)
            else:
                numeric = float(value)
                normalized.append(round(numeric, 7) if math.isfinite(numeric) else numeric)
        self._full_values[key] = normalized
        return {
            "key": key,
            "title": title,
            "description": description,
            "shape": self._shape(tensor),
            "preview": normalized[:preview_limit],
            "full_length": len(normalized),
            "row": row,
            "real_data": True,
        }

    @staticmethod
    def _token_text(tokenizer, token_id: int) -> str:
        try:
            text = tokenizer.decode([int(token_id)])
        except Exception:  # noqa: BLE001 - un ID especial puede no decodificar
            return f"<{token_id}>"
        return text.replace("\n", "↵").replace("\t", "⇥") or "∅"

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
        if not self.modelReady:
            self.error.emit("Selecciona o crea un modelo antes de abrir este laboratorio.")
            return
        source_text = str(text).strip()
        if not source_text:
            self.error.emit("Escribe un texto de entrada.")
            return
        try:
            self._analyze(
                str(module_id),
                source_text,
                int(head_index),
                float(temperature),
                int(top_k),
                float(top_p),
                bool(causal_mask),
            )
        except Exception as exc:  # noqa: BLE001 - se reporta a la interfaz
            self.error.emit(f"No se pudo analizar el modelo: {exc}")

    def _analyze(
        self,
        module_id: str,
        text: str,
        head_index: int,
        temperature: float,
        top_k: int,
        top_p: float,
        causal_mask: bool,
    ) -> None:
        model = self._model
        tokenizer = self._tokenizer
        config = model.config
        maximum = max(1, min(int(config.longitud_maxima_secuencia), 16))
        source_ids = list(tokenizer.encode(text))[:maximum]
        if not source_ids:
            raise ValueError("el tokenizador no produjo tokens")

        start_id = (
            int(config.id_token_relleno) + 1
            if config.id_token_relleno is not None
            else int(source_ids[0])
        )
        target_ids = ([start_id] + source_ids)[:maximum]
        device = next(model.parameters()).device
        source = torch.tensor([source_ids], dtype=torch.long, device=device)
        target = torch.tensor([target_ids], dtype=torch.long, device=device)
        encoder_mask, automatic_causal = model.crear_mascaras(source, target)
        selected_causal = automatic_causal
        if not causal_mask:
            selected_causal = torch.ones(
                target.size(1), target.size(1), dtype=torch.bool, device=device
            )

        was_training = bool(model.training)
        previous_capture = bool(model.capturar_traza_entrenamiento)
        try:
            model.eval()
            model.capturar_traza_entrenamiento = True
            with torch.no_grad():
                logits = model(
                    source,
                    target,
                    mascara_encoder=encoder_mask,
                    mascara_causal=selected_causal,
                )
        finally:
            model.capturar_traza_entrenamiento = previous_capture
            model.train(was_training)

        trace = model.ultima_traza or {}
        encoder_block = model.encoder.bloques[0]
        decoder_block = model.decoder.bloques[0]
        attention_trace = encoder_block.atencion.ultima_traza or {}
        decoder_self_trace = decoder_block.autoatencion.ultima_traza or {}
        cross_trace = decoder_block.atencion_cruzada.ultima_traza or {}
        head = max(0, min(head_index, int(config.num_cabezas) - 1))
        self._full_values = {}

        tokens = [
            {
                "position": index,
                "id": int(token_id),
                "text": self._token_text(tokenizer, token_id),
            }
            for index, token_id in enumerate(source_ids)
        ]
        panels: list[dict[str, Any]] = []

        if module_id == "module_1":
            panels.extend(
                [
                    self._panel("token_ids", "Token IDs", "Secuencia real producida por el tokenizador activo.", source),
                    self._panel(
                        "padding_mask",
                        "Máscara de padding",
                        "True indica una clave visible. Este ejemplo no añade PAD innecesario.",
                        encoder_mask if encoder_mask is not None else torch.ones_like(source, dtype=torch.bool),
                    ),
                ]
            )
        elif module_id == "module_2":
            panels.extend(
                [
                    self._panel("embedding", "Embedding del primer token", "Fila aprendida seleccionada por su Token ID.", trace["embedding_encoder"][0, 0]),
                    self._panel("position", "Encoding posicional", "Vector sinusoidal de la posición 0.", trace["posicion_encoder"][0, 0]),
                    self._panel("embedding_plus_position", "Suma resultante", "Embedding escalado más posición que entra al encoder.", trace["entrada_encoder"][0, 0]),
                ]
            )
        elif module_id == "module_3":
            panels.extend(
                [
                    self._panel("q", "Query real", "Consulta de la última posición, por cabeza.", attention_trace["q_ultima"]),
                    self._panel("k", "Key destacada", "Clave con mayor atención media.", attention_trace["k_destacada"]),
                    self._panel("v", "Value destacado", "Contenido entregado por la clave destacada.", attention_trace["v_destacada"]),
                    self._panel("scores", "Scores QKᵀ/√d_k", "Compatibilidades escaladas de la última consulta.", attention_trace["scores_crudos_ultima"]),
                    self._panel("attention_weights", "Pesos después de softmax", "Cada fila por cabeza suma aproximadamente uno.", attention_trace["pesos_ultima"]),
                    self._panel("attention_output", "Salida ponderada", "Mezcla de Values para la última consulta.", attention_trace["salida_proyectada_ultima"]),
                ]
            )
        elif module_id == "module_4":
            weights = encoder_block.ultimos_pesos_atencion[0, head]
            panels.extend(
                [
                    self._panel("head_attention", f"Mapa de cabeza {head + 1}", "Atención independiente de la cabeza seleccionada.", weights),
                    self._panel("head_output", "Salida de la cabeza", "Contexto de la última consulta en este subespacio.", attention_trace["salida_cabezas_ultima"][0, head]),
                    self._panel("concatenated", "Cabezas concatenadas", "Bloques contiguos antes de WO.", attention_trace["salida_concatenada_ultima"]),
                    self._panel("projected", "Salida después de WO", "Representación que mezcla todas las cabezas.", attention_trace["salida_proyectada_ultima"]),
                ]
            )
        elif module_id == "module_5":
            residual_attention = encoder_block.conexion_atencion.ultima_traza
            ffn_trace = encoder_block.feed_forward.ultima_traza
            residual_ffn = encoder_block.conexion_feed_forward.ultima_traza
            panels.extend(
                [
                    self._panel("encoder_input", "Entrada de la capa", "Último token antes de self-attention.", residual_attention["entrada"]),
                    self._panel("attention_residual", "Primera Add & Norm", "Salida real tras residual de atención y LayerNorm.", residual_attention["salida"]),
                    self._panel("ffn_hidden", "Activación FFN", f"Espacio oculto {ffn_trace['activacion_nombre']}.", ffn_trace["activacion"]),
                    self._panel("encoder_output", "Salida de la capa", "Segundo Add & Norm, listo para la siguiente capa.", residual_ffn["salida"]),
                ]
            )
        elif module_id == "module_6":
            panels.extend(
                [
                    self._panel("causal_mask", "Máscara usada", "Triangular si está activa; totalmente visible si se desactiva.", selected_causal),
                    self._panel("masked_attention", "Self-attention del decoder", "Pesos reales de la última consulta del prefijo.", decoder_self_trace["pesos_ultima"]),
                    self._panel("cross_attention", "Cross-attention", "Pesos desde el decoder hacia los tokens fuente.", cross_trace["pesos_ultima"]),
                    self._panel("decoder_output", "Salida del decoder", "Estado final de la última posición.", trace["salida_decoder"][0, -1]),
                ]
            )
        else:
            last_logits = logits[:, -1, :]
            adjusted = aplicar_temperatura(last_logits, max(temperature, 0.01))
            filtered = filtrar_top_k(adjusted, max(1, min(top_k, adjusted.size(-1))))
            filtered = filtrar_top_p(filtered, max(0.01, min(top_p, 1.0)))
            probabilities = F.softmax(filtered, dim=-1)
            selected_id = int(torch.argmax(probabilities, dim=-1).item())
            top_values, top_ids = torch.topk(probabilities[0], min(10, probabilities.size(-1)))
            candidates = [
                {
                    "id": int(token_id),
                    "text": self._token_text(tokenizer, int(token_id)),
                    "probability": round(float(probability), 7),
                }
                for probability, token_id in zip(top_values.tolist(), top_ids.tolist())
            ]
            if module_id == "module_7":
                panels.extend(
                    [
                        self._panel("logits", "Logits reales", "Salida lineal completa antes de filtros.", last_logits),
                        self._panel("probabilities", "Distribución filtrada", "Probabilidades tras Temperature, Top-K y Top-P.", probabilities),
                    ]
                )
            else:
                panels.extend(
                    [
                        self._panel("tokens", "Token IDs", "Inicio de la traza completa.", source),
                        self._panel("embedding", "Embeddings + posición", "Entrada continua del encoder.", trace["entrada_encoder"]),
                        self._panel("encoder", "Memoria del encoder", "Fuente contextualizada tras N capas.", trace["salida_encoder"]),
                        self._panel("decoder", "Estado del decoder", "Prefijo integrado con la fuente.", trace["salida_decoder"]),
                        self._panel("logits", "Logits del vocabulario", "Un score real por Token ID posible.", last_logits),
                    ]
                )
            self._result = {
                "module_id": module_id,
                "source": "real_model",
                "tokens": tokens,
                "panels": panels,
                "candidates": candidates,
                "selected_token": {
                    "id": selected_id,
                    "text": self._token_text(tokenizer, selected_id),
                },
                "model_dimensions": {
                    "d_model": int(config.dimension_modelo),
                    "heads": int(config.num_cabezas),
                    "d_head": int(config.dimension_cabeza),
                    "vocabulary": int(config.tamano_vocabulario),
                },
            }
            self.resultChanged.emit()
            self.analysisCompleted.emit(module_id)
            return

        self._result = {
            "module_id": module_id,
            "source": "real_model",
            "tokens": tokens,
            "panels": panels,
            "selected_head": head,
            "model_dimensions": {
                "d_model": int(config.dimension_modelo),
                "heads": int(config.num_cabezas),
                "d_head": int(config.dimension_cabeza),
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
