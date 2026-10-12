"""Datos exactos para animar la fórmula de cada paso del laboratorio.

Cada demostración sale del mismo forward que alimenta los paneles: los
valores se leen de las trazas del modelo o se recalculan con sus propias
capas (``nn.Linear``, ``LayerNorm``...). La vista QML solo los anima.

Los vectores largos se recortan a una ventana visible. Cuando eso ocurre en
un producto punto, la parte omitida se resume como un único término
(``hidden_sum``) para que la suma animada coincida con el resultado real.
"""

from __future__ import annotations

import math
from typing import Any, Callable

import torch
import torch.nn.functional as F


VISIBLE = 8
WIDE = 16


def _num(value: Any) -> float | None:
    """Número serializable; −∞ y NaN viajan como ``None``."""
    numeric = float(value)
    if not math.isfinite(numeric):
        return None
    return round(numeric, 6)


def _without_data(demo: dict[str, Any]) -> bool:
    """Indica si todos los campos de datos (listas y dicts) del demo están vacíos."""
    data = [value for value in demo.values() if isinstance(value, (list, tuple, dict))]
    return bool(data) and all(len(value) == 0 for value in data)


def _animation_explanation(demo: dict[str, Any], step: dict[str, Any]) -> str:
    """Describe la animación numérica, no la vista-resumen del laboratorio."""
    kind = str(demo.get("kind", ""))
    explanations = {
        "split_text": "Sigue el barrido de izquierda a derecha: cada fragmento aparece en el orden exacto en que el tokenizador recorre el texto.",
        "lookup_ids": "Observa cómo cada token se empareja con su índice y cómo esos índices se reúnen, en el mismo orden, en el tensor de IDs.",
        "specials": "Mira cómo BOS se inserta al principio, EOS al final y la secuencia resultante queda alineada con la entrada del decoder.",
        "padding": "Compara las longitudes y sigue las celdas PAD que aparecen únicamente hasta completar la matriz rectangular B × T.",
        "mask_compare": "La animación compara cada ID con PAD: las posiciones válidas permanecen activas y las de relleno cambian a bloqueadas.",
        "no_grad": "Sigue la señal de backward hasta el límite del tokenizador; el símbolo ∅ marca que no existen parámetros diferenciables que actualizar.",
        "lookup_row": "Observa cómo el ID señala una fila concreta de la tabla E y cómo esa fila se copia como vector del token.",
        "map": "Lee cada coordenada de entrada y su salida correspondiente; el cambio se aplica elemento a elemento sin mezclar posiciones.",
        "positional": "Sigue frecuencia, ángulo y seno/coseno para una coordenada; al final las coordenadas calculadas forman el vector PE.",
        "sum": "Mira una coordenada a la vez: aparece el primer sumando, se añade el segundo y se revela la coordenada resultante.",
        "matrix_rows": "Cada token aporta una fila a la matriz; el resaltado final identifica la fila del token seleccionado.",
        "heatmaps": "La animación revela WQ, WK y WV por separado; compara signo y magnitud mediante la misma escala de color.",
        "projection": "Sigue los productos de una salida: cada entrada se multiplica por su peso, los términos se acumulan, se añade el sesgo y aparece el resultado.",
        "mask_row": "Compara cada score con la máscara; los permitidos se conservan y los bloqueados se sustituyen antes de Softmax.",
        "softmax": "Sigue una fila completa: los scores se exponencian, se suman y después cada término se divide por el total para obtener pesos.",
        "weighted_sum": "Observa cómo cada peso escala su vector Value y cómo las contribuciones se acumulan coordenada a coordenada hasta formar el contexto.",
        "multi_softmax": "Las filas se normalizan cabeza por cabeza; el foco final permite comparar dónde concentra su peso cada cabeza.",
        "layernorm": "Sigue la suma residual, el cálculo de μ, el centrado, la división por σ y, al final, la transformación aprendida con γ y β.",
        "activation": "Compara cada preactivación con su salida después de φ; el recorrido resalta dónde la función conserva, atenúa o anula valores.",
        "ffn": "Sigue el vector al expandirse con W₁, atravesar la no linealidad y comprimirse con W₂ hasta recuperar d_model.",
        "stack": "El mismo token asciende capa por capa; cada nivel sustituye su vector anterior y el último se marca como salida final.",
        "cross_entropy": "Sigue los logits hasta Softmax, localiza la probabilidad del token objetivo y observa cómo −log(p) produce la pérdida.",
        "argmax": "La animación recorre las probabilidades, conserva temporalmente el mayor valor y resalta el token ganador al final.",
        "append": "Mira cómo el token elegido se anexa al extremo del prefijo y cómo esa nueva secuencia queda lista para otra iteración.",
        "backward": "La señal parte de la pérdida y avanza en sentido inverso; las barras finales muestran la magnitud del gradiente recibido por cada parámetro.",
        "update": "Compara θ con el término η·g y observa la resta coordenada a coordenada que produciría θ′ sin escribirla en el modelo.",
        "vector": "Las coordenadas se revelan en conjunto y la marca final resume la magnitud del vector mediante su norma.",
        "causal_mask": "La animación recorre cada celda (i,j): permite j ≤ i y bloquea el futuro hasta completar el triángulo causal.",
        "unavailable": "La animación no dispone de datos numéricos para este paso; revisa el mensaje mostrado en el área central.",
    }
    if kind == "heads":
        mode = str(demo.get("mode", ""))
        if mode == "split":
            return "Sigue cómo el vector d_model se divide en h bloques consecutivos; cada bloque termina en la fila de una cabeza distinta."
        if mode == "concat":
            return "Observa cómo los contextos de las cabezas se alinean y se unen sin promediarse hasta reconstruir un vector d_model."
        return "Sigue la concatenación de las cabezas y la mezcla posterior con Wᴼ; el último vector es la salida multi-head."
    if kind == "shift":
        if bool(demo.get("training")):
            return "Compara objetivo y entrada desplazada: BOS abre la entrada y cada posición queda emparejada con el token que debe predecir."
        return "Sigue el prefijo ya generado y observa la posición vacía al final, que es donde el decoder debe producir el siguiente token."
    if kind == "sampling":
        return "Sigue los candidatos a través de cada filtro activo: cambian sus logits o desaparecen hasta quedar el conjunto que participará en la elección."
    return explanations.get(
        kind,
        "Sigue las fases de la barra inferior y relaciona cada cambio numérico con la salida «"
        + str(step.get("output", "del paso")) + "».",
    )


def _flat(tensor: torch.Tensor) -> torch.Tensor:
    return tensor.detach().float().cpu().reshape(-1)


def _vec(tensor: torch.Tensor, limit: int = VISIBLE) -> list[float | None]:
    return [_num(value) for value in _flat(tensor)[:limit].tolist()]


def _matrix(tensor: torch.Tensor, rows: int = 6, columns: int = 6) -> list[list[float | None]]:
    value = tensor.detach().float().cpu()
    while value.dim() > 2:
        value = value[0]
    if value.dim() < 2:
        value = value.reshape(1, -1)
    return [[_num(cell) for cell in row] for row in value[:rows, :columns].tolist()]


def _square(mask: torch.Tensor) -> torch.Tensor:
    value = mask.detach().cpu()
    while value.dim() > 2:
        value = value[0]
    return value


def _dot_output(
    vector: torch.Tensor,
    weights: torch.Tensor,
    *,
    label: str,
    w_label: str,
    result_label: str,
    bias: torch.Tensor | float | None = None,
    divisor: float | None = None,
    vector_values: torch.Tensor | None = None,
    vector_labels: list[str] | None = None,
    highlight: int = 0,
    segments: int = 0,
) -> dict[str, Any]:
    """Un producto punto completo con su ventana visible y el resto resumido."""
    a = _flat(vector)
    b = _flat(weights)
    products = a * b
    shown = min(VISIBLE, products.numel())
    # El sesgo puede ser un parámetro del modelo con requires_grad; sin
    # detach() PyTorch avisa en cada ejecución y ensucia la consola.
    if isinstance(bias, torch.Tensor):
        bias = bias.detach()
    bias_value = None if bias is None else float(bias)
    total = float(products.sum().item()) + (bias_value or 0.0)
    if divisor:
        total /= divisor
    values = _flat(vector_values) if vector_values is not None else None
    width = WIDE if vector_labels is None else len(vector_labels)
    return {
        "label": label,
        "w_label": w_label,
        "result_label": result_label,
        "w": [_num(v) for v in b[:shown].tolist()],
        "products": [_num(v) for v in products[:shown].tolist()],
        "hidden_terms": int(products.numel() - shown),
        "hidden_sum": _num(products[shown:].sum().item()) if products.numel() > shown else 0.0,
        "bias": _num(bias_value) if bias_value is not None else None,
        "divisor": _num(divisor) if divisor else None,
        "result": _num(total),
        "vector": [_num(v) for v in values[:width].tolist()] if values is not None else [],
        "vector_labels": vector_labels or [],
        "vector_size": int(values.numel()) if values is not None else 0,
        "highlight": int(highlight),
        "segments": int(segments),
    }


def _projection(
    title: str,
    caption: str,
    input_label: str,
    vector: torch.Tensor,
    outputs: list[dict[str, Any]],
) -> dict[str, Any]:
    flat = _flat(vector)
    return {
        "kind": "projection",
        "title": title,
        "caption": caption,
        "input_label": input_label,
        "input": [_num(v) for v in flat[:VISIBLE].tolist()],
        "input_size": int(flat.numel()),
        "outputs": outputs,
    }


def _sum(title, caption, a_label, b_label, c_label, a, b, c, column_label="d"):
    flat = _flat(c)
    return {
        "kind": "sum",
        "title": title,
        "caption": caption,
        "a_label": a_label,
        "b_label": b_label,
        "c_label": c_label,
        "a": _vec(a),
        "b": _vec(b),
        "c": _vec(c),
        "size": int(flat.numel()),
        "column_label": column_label,
    }


def _map(title, caption, input_label, output_label, operator, operand, inputs, outputs,
         labels=None, dropped=None):
    flat = _flat(inputs)
    limit = len(labels) if labels else VISIBLE
    return {
        "kind": "map",
        "title": title,
        "caption": caption,
        "input_label": input_label,
        "output_label": output_label,
        "operator": operator,
        "operand": _num(operand) if operand is not None else None,
        "inputs": _vec(inputs, limit),
        "outputs": _vec(outputs, limit),
        "labels": labels or [],
        "dropped": dropped or [],
        "size": int(flat.numel()),
    }


def _layer_norm(title, caption, norm: torch.nn.LayerNorm, a_label, b_label, a, b, x, out):
    values = _flat(x)
    mean = float(values.mean().item())
    variance = float(values.var(unbiased=False).item())
    std = math.sqrt(variance + float(norm.eps))
    normalized = (values - mean) / std
    gamma = _flat(norm.weight)
    beta = _flat(norm.bias) if norm.bias is not None else torch.zeros_like(gamma)
    return {
        "kind": "layernorm",
        "title": title,
        "caption": caption,
        "a_label": a_label,
        "b_label": b_label,
        "a": _vec(a) if a is not None else [],
        "b": _vec(b) if b is not None else [],
        "x": _vec(values),
        "mean": _num(mean),
        "variance": _num(variance),
        "std": _num(std),
        "eps": float(norm.eps),
        "normalized": _vec(normalized),
        "gamma": _vec(gamma),
        "beta": _vec(beta),
        "output": _vec(out),
        "size": int(values.numel()),
    }


def _softmax(title, caption, labels, scores: torch.Tensor, allowed, probabilities,
             query_label, rest=None):
    raw = [float(v) for v in _flat(scores).tolist()]
    finite = [s for s, ok in zip(raw, allowed) if ok and math.isfinite(s)]
    shift = max(finite) if finite and max(finite) > 30 else 0.0
    exps = [
        math.exp(s - shift) if ok and math.isfinite(s) else 0.0
        for s, ok in zip(raw, allowed)
    ]
    total = sum(exps) + (rest["exp_sum"] if rest else 0.0)
    return {
        "kind": "softmax",
        "title": title,
        "caption": caption,
        "labels": labels,
        "scores": [_num(s) if ok else None for s, ok in zip(raw, allowed)],
        "allowed": [bool(ok) for ok in allowed],
        "exps": [_num(e) for e in exps],
        "shift": _num(shift),
        "total": _num(total),
        "probs": _vec(probabilities, len(labels)),
        "query_label": query_label,
        "rest_count": int(rest["count"]) if rest else 0,
        "rest_exp": _num(rest["exp_sum"]) if rest else 0.0,
        "rest_prob": _num(rest["prob"]) if rest else 0.0,
    }


def _weighted(title, caption, labels, weights, vectors, result, query_label, extra=None):
    return {
        "kind": "weighted_sum",
        "title": title,
        "caption": caption,
        "labels": labels,
        "weights": _vec(weights, len(labels)),
        "vectors": _matrix(vectors, len(labels), 6),
        "result": _vec(result, 6),
        "dims": int(vectors.size(-1)),
        "query_label": query_label,
        "extra": extra or {},
    }


def _stack(title, caption, token_label, states: list[tuple[str, torch.Tensor]]):
    return {
        "kind": "stack",
        "title": title,
        "caption": caption,
        "token_label": token_label,
        "layers": [
            {
                "label": label,
                "values": _vec(state),
                "norm": _num(_flat(state).norm().item()),
            }
            for label, state in states
        ],
        "size": int(_flat(states[0][1]).numel()) if states else 0,
    }


class FormulaDemoBuilder:
    """Construye ``{step_id: demo}`` para el módulo y modo explorados."""

    def __init__(self, ctx: dict[str, Any], token_text: Callable[[Any, int], str]) -> None:
        self.ctx = ctx
        self.model = ctx["model"]
        self.tokenizer = ctx["tokenizer"]
        self.config = self.model.config
        self.mode = ctx["mode"]
        self.training = self.mode == "training"
        self.prepared = ctx["prepared"]
        self.trace = ctx["trace"]
        self.layer = ctx["layer"]
        self.head = ctx["head"]
        self.selected = ctx["selected_token"]
        self._token_text = token_text

    # ------------------------------------------------------------ utilidades
    def label(self, token_id: int) -> str:
        token_id = int(token_id)
        if token_id == self.prepared.get("bos"):
            return "BOS"
        if self.prepared.get("eos") is not None and token_id == self.prepared["eos"]:
            return "EOS"
        if self.prepared.get("pad") is not None and token_id == self.prepared["pad"]:
            return "PAD"
        return self._token_text(self.tokenizer, token_id)

    def chips(self, ids) -> list[dict[str, Any]]:
        return [{"text": self.label(i), "id": int(i)} for i in ids]

    def source_labels(self) -> list[str]:
        return [self.label(i) for i in self.prepared["source"][0].tolist()]

    def target_labels(self) -> list[str]:
        return [self.label(i) for i in self.prepared["target"][0].tolist()]

    def source_index(self) -> int:
        return max(0, min(self.selected, self.prepared["source"].size(1) - 1))

    def target_index(self) -> int:
        return max(0, min(self.selected, self.prepared["target"].size(1) - 1))

    def output_position(self) -> int:
        logits = self.ctx["logits"]
        if self.training:
            return max(0, min(self.selected, logits.size(1) - 1))
        return logits.size(1) - 1

    @staticmethod
    def sub(index: int) -> str:
        digits = "₀₁₂₃₄₅₆₇₈₉"
        return "".join(digits[int(d)] for d in str(int(index)))

    def build(self, module_id: str, steps: list[dict[str, Any]]) -> dict[str, Any]:
        builder = getattr(self, f"_{module_id}", None)
        if builder is None:
            return {}
        demos: dict[str, Any] = {}
        for step in steps:
            identifier = str(step["id"])
            try:
                demo = builder(identifier)
            except Exception as exc:  # noqa: BLE001 - una animación nunca rompe el laboratorio
                demo = {"kind": "unavailable", "title": step.get("formula", ""),
                        "caption": f"No se pudo preparar la animación: {exc}"}
            if demo is None:
                demo = self._training_demo(identifier)
            if demo is not None and _without_data(demo):
                # Una animación sin un solo dato se dibujaría como un marco
                # vacío. Algunos campos son opcionales y vacíos con razón
                # (``dropped``, ``extra``), por eso solo se descarta cuando
                # todos lo están.
                demo = {"kind": "unavailable", "title": step.get("formula", ""),
                        "caption": "No se pudo preparar la animación: el paso "
                                   f"«{identifier}» no produjo datos que animar."}
            if demo is not None:
                demo.setdefault("formula", step.get("formula", ""))
                demo.setdefault("animation_explanation", _animation_explanation(demo, step))
                demos[identifier] = demo
        return demos

    # -------------------------------------------------- señal de aprendizaje
    def _gradient_row(self) -> int:
        """Fila de la ventana con más señal: muchas filas de E no reciben gradiente."""
        panel = self.ctx["panels"].get("component_gradient") or {}
        matrix = panel.get("matrix") or []
        if not matrix:
            return 0
        return max(range(len(matrix)), key=lambda r: sum(abs(float(v or 0)) for v in matrix[r]))

    def _panel_row(self, key: str) -> list[float | None]:
        panel = self.ctx["panels"].get(key) or {}
        matrix = panel.get("matrix") or []
        if not matrix:
            return []
        row = min(self._gradient_row(), len(matrix) - 1)
        return [cell for cell in matrix[row][:VISIBLE]]

    def _training_demo(self, identifier: str) -> dict[str, Any] | None:
        snapshot = self.ctx.get("training_snapshot") or {}
        name = str(snapshot.get("representative_parameter") or "θ")
        shape = next((item.get("shape") for item in snapshot.get("gradients") or []
                      if item.get("name") == name), None)
        if shape and len(shape) > 1:
            name = f"{name}[{self._gradient_row()}]"
        if identifier.endswith("gradient") or identifier.endswith("backward"):
            gradients = sorted(
                snapshot.get("gradients") or [],
                key=lambda item: -float(item.get("norm_l2") or 0.0),
            )[:4]
            return {
                "kind": "backward",
                "title": f"g = ∂L/∂{name}   ·   L = {snapshot.get('loss', 0):.4f}",
                "caption": "La señal parte de la pérdida real y recorre el cálculo en sentido inverso; "
                           "cada celda es la derivada de L respecto de un peso real del componente.",
                "loss": snapshot.get("loss"),
                "parameter": name,
                "gradient": self._panel_row("component_gradient"),
                "gradient_norm": snapshot.get("gradient_norm"),
                "parameters": [
                    {"label": item.get("label"), "norm": item.get("norm_l2")}
                    for item in gradients
                ],
            }
        if identifier.endswith("update"):
            learning_rate = float(snapshot.get("hypothetical_learning_rate") or 1e-3)
            return {
                "kind": "update",
                "title": f"{name}′ = {name} − {learning_rate:g} · g",
                "caption": "Cada peso se desplaza en sentido contrario a su gradiente. "
                           "El resultado se calcula, pero no se escribe en el modelo.",
                "parameter": name,
                "learning_rate": learning_rate,
                "theta": self._panel_row("parameter_before"),
                "gradient": self._panel_row("component_gradient"),
                "updated": self._panel_row("hypothetical_update"),
            }
        return None

    # ------------------------------------------------------------- módulo 1
    def _module_1(self, identifier: str) -> dict[str, Any] | None:
        source_ids = list(self.prepared["source_ids"])
        pieces = [
            {"text": self.label(i), "id": int(i), "position": index}
            for index, i in enumerate(source_ids)
        ]
        pad = self.prepared.get("pad")
        rows = self.prepared["source"].tolist()
        if identifier in {"text", "tokens"}:
            return {
                "kind": "split_text",
                "title": f"«{self.ctx['text']}» → {len(pieces)} tokens",
                "caption": "El tokenizador recorre el texto y lo corta en las piezas de su vocabulario."
                           if identifier == "text" else
                           "Cada pieza conserva su lugar: el subíndice es la posición, no la importancia.",
                "text": self.ctx["text"],
                "pieces": pieces,
                "show_positions": identifier == "tokens",
            }
        if identifier == "ids":
            return {
                "kind": "lookup_ids",
                "title": "[" + ", ".join(str(p["id"]) for p in pieces) + "]",
                "caption": "Cada token se busca en el vocabulario y se reemplaza por el índice de su fila.",
                "pieces": pieces,
                "vocabulary": int(self.config.tamano_vocabulario),
            }
        if identifier == "specials":
            bos = self.prepared["bos"]
            eos = self.prepared.get("eos")
            sequence = [bos, *source_ids] + ([eos] if eos is not None else [])
            return {
                "kind": "specials",
                "title": "[BOS] + ids + [EOS] = [" + ", ".join(str(i) for i in sequence) + "]",
                "caption": "BOS abre la secuencia y EOS marca su cierre; el decoder recibe la versión desplazada.",
                "content": self.chips(source_ids),
                "bos": {"text": "BOS", "id": int(bos)},
                "eos": {"text": "EOS", "id": int(eos)} if eos is not None else None,
                "decoder": self.chips(self.prepared["target"][0].tolist()),
            }
        if identifier == "batch":
            if self.training:
                lengths = []
                for row in rows:
                    length = len(row)
                    while pad is not None and length > 0 and row[length - 1] == pad:
                        length -= 1
                    lengths.append(length)
                return {
                    "kind": "padding",
                    "title": f"longitudes {lengths} → matriz {len(rows)}×{len(rows[0])}",
                    "caption": "Las filas cortas se completan con PAD hasta la longitud de la más larga.",
                    "training": True,
                    "rows": [self.chips(row) for row in rows],
                    "lengths": lengths,
                    "pad_id": pad,
                }
            original = [int(v) for v in list(self.tokenizer.encode(self.ctx["text"]))]
            limit = max(1, min(int(self.config.longitud_maxima_secuencia), 16))
            return {
                "kind": "padding",
                "title": f"ids[:{limit}] → {min(len(original), limit)} de {len(original)} tokens",
                "caption": "En inferencia no se rellena: solo se conservan las primeras Tmax posiciones.",
                "training": False,
                "rows": [self.chips(original)],
                "limit": limit,
                "pad_id": pad,
            }
        if identifier == "mask":
            mask = [[pad is None or int(v) != int(pad) for v in row] for row in rows]
            return {
                "kind": "mask_compare",
                "title": f"M = ids ≠ PAD({pad})",
                "caption": "Cada celda compara su ID con PAD: verdadero se conserva, falso se bloqueará en atención.",
                "rows": [self.chips(row) for row in rows],
                "mask": mask,
                "pad_id": pad,
            }
        if identifier == "no_grad":
            snapshot = self.ctx.get("training_snapshot") or {}
            return {
                "kind": "no_grad",
                "title": "∂L/∂tokenizador = ∅",
                "caption": "El gradiente llega hasta los embeddings, pero no puede atravesar una búsqueda de índices enteros.",
                "pieces": pieces,
                "loss": snapshot.get("loss") if self.training else None,
            }
        return None

    # ------------------------------------------------------------- módulo 2
    def _module_2(self, identifier: str) -> dict[str, Any] | None:
        index = self.source_index()
        token_id = int(self.prepared["source"][0, index].item())
        token = self.label(token_id)
        d_model = int(self.config.dimension_modelo)
        trace = self.trace
        embedding = trace["embedding_encoder"][0, index]
        scaled = trace["embedding_encoder_escalado"][0, index]
        position = trace["posicion_encoder"][0, index]
        summed = trace["entrada_encoder"][0, index]
        dropped = trace["entrada_encoder_dropout"][0, index]
        if identifier == "lookup":
            table = self.model.embedding_entrada.embedding.weight
            first = max(0, token_id - 2)
            last = min(table.size(0) - 1, token_id + 2)
            return {
                "kind": "lookup_row",
                "title": f"e{self.sub(index)} = E[{token_id}]  («{token}»)",
                "caption": "El ID no se multiplica: funciona como dirección y selecciona una fila de la tabla aprendida E.",
                "token": token,
                "token_id": token_id,
                "rows": [
                    {"id": row, "values": _vec(table[row], 6), "selected": row == token_id}
                    for row in range(first, last + 1)
                ],
                "vector": _vec(embedding),
                "size": d_model,
                "vocabulary": int(table.size(0)),
            }
        if identifier == "scale":
            factor = math.sqrt(d_model)
            return _map(
                f"ẽ{self.sub(index)} = e{self.sub(index)} · √{d_model} = e{self.sub(index)} · {factor:.4f}",
                "Cada coordenada del embedding se multiplica por el mismo escalar √d_model.",
                f"e{self.sub(index)}", f"ẽ{self.sub(index)}", "×", factor, embedding, scaled,
            )
        if identifier == "position":
            dims = []
            for column in range(min(VISIBLE, d_model)):
                pair = column // 2
                exponent = 2 * pair / d_model
                angle = index / (10000 ** exponent)
                dims.append({
                    "column": column,
                    "pair": pair,
                    "exponent": _num(exponent),
                    "angle": _num(angle),
                    "function": "sin" if column % 2 == 0 else "cos",
                    "value": _num(position[column].item()),
                })
            return {
                "kind": "positional",
                "title": f"PE({index}, ·) con d = {d_model}",
                "caption": "Cada par de dimensiones usa una frecuencia distinta; la posición fija el ángulo y seno/coseno dan el valor.",
                "position": index,
                "size": d_model,
                "token": token,
                "dims": dims,
            }
        if identifier == "sum":
            return _sum(
                f"x{self.sub(index)} = ẽ{self.sub(index)} + PE{self.sub(index)}",
                "La suma es coordenada a coordenada: contenido aprendido + orden fijo.",
                f"ẽ{self.sub(index)}", f"PE{self.sub(index)}", f"x{self.sub(index)}",
                scaled, position, summed,
            )
        if identifier == "dropout":
            if self.training:
                probability = float(self.config.dropout)
                flags = [
                    bool(out == 0.0 and inp != 0.0)
                    for inp, out in zip(_flat(summed)[:VISIBLE].tolist(), _flat(dropped)[:VISIBLE].tolist())
                ]
                factor = 1.0 / (1.0 - probability) if probability < 1 else 0.0
                return _map(
                    f"x̃ = máscara · x / (1 − {probability:g})",
                    f"Con p = {probability:g}, algunas coordenadas se anulan al azar y las demás se multiplican por {factor:.4f}.",
                    "x", "x̃", "×", factor, summed, dropped, dropped=flags,
                )
            return _map(
                "x̃ = x  (Dropout desactivado)",
                "En inferencia Dropout es la identidad: cada coordenada pasa sin cambios.",
                "x", "x̃", "×", 1.0, summed, dropped,
            )
        return None

    # ------------------------------------------------------- atención (3, 4)
    def _attention(self, block, x: torch.Tensor, memory: torch.Tensor | None, head: int):
        attention = block
        with torch.no_grad():
            source = x if memory is None else memory
            q = attention._separar_cabezas(attention.proyeccion_q(x))[0]
            k = attention._separar_cabezas(attention.proyeccion_k(source))[0]
            v = attention._separar_cabezas(attention.proyeccion_v(source))[0]
            raw = q @ k.transpose(-2, -1)
            scaled = raw / math.sqrt(attention.dimension_cabeza)
        return {"q": q, "k": k, "v": v, "raw": raw, "scaled": scaled, "head": head}

    def _encoder_attention(self):
        block = self.model.encoder.bloques[self.layer]
        x = block.conexion_atencion.ultima_traza["entrada_visual"]
        attention = block.atencion
        data = self._attention(attention, x, None, self.head)
        data["module"] = attention
        data["x"] = x[0]
        data["weights"] = attention.ultimos_pesos_atencion[0]
        data["contexts"] = data["weights"] @ data["v"]
        with torch.no_grad():
            data["concatenated"] = attention._combinar_cabezas(data["contexts"].unsqueeze(0))[0]
            data["projected"] = attention.proyeccion_salida(data["concatenated"])
        data["query"] = max(0, min(self.selected, x.size(1) - 1))
        return data

    def _module_3(self, identifier: str) -> dict[str, Any] | None:
        data = self._encoder_attention()
        attention = data["module"]
        head = self.head
        i = data["query"]
        labels = self.source_labels()[: data["x"].size(0)]
        weights = data["weights"][head, i]
        j = int(weights.argmax().item())
        d_head = int(attention.dimension_cabeza)
        start = head * d_head
        hs = self.sub(i)
        if identifier == "attention_input":
            x = data["x"]
            return {
                "kind": "matrix_rows",
                "title": f"X ∈ ℝ^({x.size(0)}×{x.size(1)})",
                "caption": "Cada token aporta una fila; juntas forman la matriz X que recibe la atención.",
                "row_labels": labels,
                "matrix": _matrix(x, len(labels), 6),
                "selected": i,
                "shape": [int(x.size(0)), int(x.size(1))],
                "symbol": "X",
            }
        if identifier == "weights":
            items = []
            for name, linear in (("W_Q", attention.proyeccion_q), ("W_K", attention.proyeccion_k),
                                 ("W_V", attention.proyeccion_v)):
                block = linear.weight[start:start + d_head]
                items.append({"label": name, "matrix": _matrix(block),
                              "shape": [int(block.size(1)), int(block.size(0))]})
            return {
                "kind": "heatmaps",
                "title": f"Cabeza {head + 1}: tres matrices de {int(self.config.dimension_modelo)}×{d_head}",
                "caption": "Son pesos aprendidos, iguales para todos los tokens; el color indica signo y magnitud.",
                "items": items,
            }
        if identifier == "qkv":
            x_i = data["x"][i]
            outputs = []
            for name, linear, tensor in (("Q", attention.proyeccion_q, data["q"]),
                                         ("K", attention.proyeccion_k, data["k"]),
                                         ("V", attention.proyeccion_v, data["v"])):
                outputs.append(_dot_output(
                    x_i, linear.weight[start],
                    label=name, w_label=f"W_{name}[:,0]",
                    result_label=f"{name.lower()}{hs}[0]",
                    bias=linear.bias[start] if linear.bias is not None else None,
                    vector_values=tensor[head, i], highlight=0,
                ))
            return _projection(
                f"q{hs} = x{hs}W_Q · k{hs} = x{hs}W_K · v{hs} = x{hs}W_V",
                "La misma fila x se multiplica por tres matrices distintas; se muestra la primera coordenada de cada proyección.",
                f"x{hs} («{labels[i]}»)", data["x"][i], outputs,
            )
        if identifier == "dot":
            output = _dot_output(
                data["q"][head, i], data["k"][head, j],
                label="S₀", w_label=f"k{self.sub(j)} («{labels[j]}»)",
                result_label=f"S₀[{i},{j}]",
                vector_values=data["raw"][head, i], vector_labels=labels, highlight=j,
            )
            return _projection(
                f"S₀[{i},{j}] = q{hs} · k{self.sub(j)}",
                "Se multiplican coordenada a coordenada la query y la key y se suman: una compatibilidad sin normalizar.",
                f"q{hs} («{labels[i]}»)", data["q"][head, i], [output],
            )
        if identifier == "scale":
            factor = math.sqrt(d_head)
            return _map(
                f"S[{i},:] = S₀[{i},:] / √{d_head} = S₀[{i},:] / {factor:.4f}",
                "Toda la fila de scores se divide entre √d_k para controlar su escala antes de Softmax.",
                f"S₀[{i},:]", f"S[{i},:]", "÷", factor,
                data["raw"][head, i], data["scaled"][head, i], labels=labels,
            )
        mask = self.prepared["encoder_mask"]
        allowed = (
            [bool(v) for v in _square(mask)[-1].tolist()][: len(labels)]
            if mask is not None else [True] * len(labels)
        )
        if identifier == "mask":
            scores = [_num(v) for v in data["scaled"][head, i].tolist()]
            return {
                "kind": "mask_row",
                "title": f"S′[{i},:] = mask(S[{i},:])",
                "caption": "Cada key permitida conserva su score; una key de PAD se sustituye por −∞."
                           if not all(allowed) else
                           "Esta secuencia no tiene PAD: todas las keys siguen permitidas y los scores no cambian.",
                "labels": labels,
                "scores": scores,
                "allowed": allowed,
                "query_label": labels[i],
            }
        if identifier == "softmax":
            return _softmax(
                f"A[{i},:] = softmax(S′[{i},:])",
                "Cada score se exponencia, se suman todos y cada exponencial se divide entre esa suma.",
                labels, data["scaled"][head, i], allowed, weights, labels[i],
            )
        if identifier == "weighted":
            return _weighted(
                f"C{hs} = Σⱼ A[{i},j] · vⱼ",
                "Cada Value se escala por su peso y las contribuciones se acumulan en el contexto.",
                labels, weights, data["v"][head], data["contexts"][head, i], labels[i],
            )
        if identifier == "output":
            return {
                "kind": "heads",
                "mode": "concat_project",
                "title": f"y{hs} = Concat(C₁…C{self.sub(attention.num_cabezas)}) · Wᴼ",
                "caption": "Los contextos de las cabezas se colocan uno junto a otro y Wᴼ los mezcla de regreso a d_model.",
                "heads": [_vec(data["contexts"][h, i], 4) for h in range(attention.num_cabezas)],
                "d_head": d_head,
                "vector": _vec(data["concatenated"][i], WIDE),
                "projected": _vec(data["projected"][i], WIDE),
                "size": int(data["concatenated"].size(-1)),
                "selected_head": head,
            }
        return None

    def _module_4(self, identifier: str) -> dict[str, Any] | None:
        data = self._encoder_attention()
        attention = data["module"]
        heads = int(attention.num_cabezas)
        d_head = int(attention.dimension_cabeza)
        i = data["query"]
        hs = self.sub(i)
        labels = self.source_labels()[: data["x"].size(0)]
        with torch.no_grad():
            q_full = attention.proyeccion_q(data["x"])[i]
        if identifier == "project":
            outputs = []
            for name, linear in (("Q", attention.proyeccion_q), ("K", attention.proyeccion_k),
                                 ("V", attention.proyeccion_v)):
                with torch.no_grad():
                    full = linear(data["x"][i])
                outputs.append(_dot_output(
                    data["x"][i], linear.weight[0],
                    label=name, w_label=f"W_{name}[:,0]", result_label=f"{name.lower()}{hs}[0]",
                    bias=linear.bias[0] if linear.bias is not None else None,
                    vector_values=full, highlight=0, segments=heads,
                ))
            return _projection(
                f"[q{hs} | k{hs} | v{hs}] = x{hs} · [W_Q | W_K | W_V]",
                "Una sola proyección produce todas las coordenadas de todas las cabezas (colores = cabezas).",
                f"x{hs} («{labels[i]}»)", data["x"][i], outputs,
            )
        if identifier == "split":
            return {
                "kind": "heads",
                "mode": "split",
                "title": f"q{hs} ∈ ℝ^{int(self.config.dimension_modelo)} → {heads} × ℝ^{d_head}",
                "caption": "El vector no se recalcula: se corta en bloques consecutivos de d_head, uno por cabeza.",
                "heads": [_vec(data["q"][h, i], 4) for h in range(heads)],
                "d_head": d_head,
                "vector": _vec(q_full, WIDE),
                "size": int(q_full.numel()),
                "selected_head": self.head,
            }
        if identifier == "maps":
            return {
                "kind": "multi_softmax",
                "title": f"A_h[{i},:] = softmax(Q_hK_hᵀ/√{d_head})   h = 1…{heads}",
                "caption": "Cada cabeza compara la misma query con sus propias keys y obtiene una distribución distinta.",
                "labels": labels,
                "query_label": labels[i],
                "heads": [
                    {"scores": _vec(data["scaled"][h, i], len(labels)),
                     "probs": _vec(data["weights"][h, i], len(labels))}
                    for h in range(min(heads, 8))
                ],
                "selected_head": self.head,
            }
        if identifier == "contexts":
            head = self.head
            return _weighted(
                f"C_{head + 1}[{i}] = Σⱼ A_{head + 1}[{i},j] · v_{head + 1},ⱼ",
                "La cabeza seleccionada mezcla sus propios Values usando su propio mapa de atención.",
                labels, data["weights"][head, i], data["v"][head], data["contexts"][head, i], labels[i],
            )
        if identifier == "concat":
            return {
                "kind": "heads",
                "mode": "concat",
                "title": f"C{hs} = Concat(C₁…C{self.sub(heads)}) ∈ ℝ^{int(self.config.dimension_modelo)}",
                "caption": "Los contextos de cada cabeza se colocan uno detrás de otro; no se promedian.",
                "heads": [_vec(data["contexts"][h, i], 4) for h in range(heads)],
                "d_head": d_head,
                "vector": _vec(data["concatenated"][i], WIDE),
                "size": int(data["concatenated"].size(-1)),
                "selected_head": self.head,
            }
        if identifier == "wo":
            linear = attention.proyeccion_salida
            output = _dot_output(
                data["concatenated"][i], linear.weight[0],
                label="Y", w_label="Wᴼ[:,0]", result_label=f"y{hs}[0]",
                bias=linear.bias[0] if linear.bias is not None else None,
                vector_values=data["projected"][i], highlight=0,
            )
            return _projection(
                f"y{hs} = C{hs} · Wᴼ",
                "Cada coordenada de salida mezcla coordenadas de todas las cabezas a la vez.",
                f"C{hs}", data["concatenated"][i], [output],
            )
        return None

    # ------------------------------------------------------------- módulo 5
    def _ffn_parts(self, feed_forward, x: torch.Tensor):
        with torch.no_grad():
            pre = feed_forward.capa_expansion(x)
            act = feed_forward.activacion(pre)
            out = feed_forward.capa_proyeccion(act)
        return pre, act, out

    def _module_5(self, identifier: str) -> dict[str, Any] | None:
        block = self.model.encoder.bloques[self.layer]
        first = block.conexion_atencion.ultima_traza
        second = block.conexion_feed_forward.ultima_traza
        t = max(0, min(self.source_index(), first["entrada_visual"].size(1) - 1))
        labels = self.source_labels()[: first["entrada_visual"].size(1)]
        ts = self.sub(t)
        layer = self.layer
        x = first["entrada_visual"][0, t]
        update = first["actualizacion_visual"][0, t]
        r1 = first["antes_norma_visual"][0, t]
        n1 = first["salida_visual"][0, t]
        ff = block.feed_forward
        pre, act, out = self._ffn_parts(ff, n1)
        activation = ff.activacion.__class__.__name__
        if identifier == "encoder_input":
            matrix = first["entrada_visual"][0]
            return {
                "kind": "matrix_rows",
                "title": f"X_{layer} ∈ ℝ^({matrix.size(0)}×{matrix.size(1)})  ·  capa {layer + 1}",
                "caption": "Cada fila es un token tal como llega a esta capa; el resaltado sigue al token elegido.",
                "row_labels": labels,
                "matrix": _matrix(matrix, len(labels), 6),
                "selected": t,
                "shape": [int(matrix.size(0)), int(matrix.size(1))],
                "symbol": f"X_{layer}",
            }
        if identifier == "encoder_attention":
            data = self._encoder_attention()
            head = self.head
            return _weighted(
                f"MHA(X_{layer})[{t}]: cabeza {head + 1} mezcla Values",
                "La cabeza elegida mezcla los Values con sus pesos; Wᴼ combina todas las cabezas en la actualización.",
                labels, data["weights"][head, t], data["v"][head], data["contexts"][head, t], labels[t],
                extra={"label": f"MHA(X_{layer}){ts} tras Wᴼ", "values": _vec(update, 6)},
            )
        if identifier == "residual_1":
            return _sum(
                f"R₁ = X_{layer} + MHA(X_{layer})   (token «{labels[t]}»)",
                "El atajo conserva la entrada y la atención aporta la actualización; se suman coordenada a coordenada.",
                f"X_{layer}", "MHA", "R₁", x, update, r1,
            )
        if identifier == "norm_1":
            return _layer_norm(
                "N₁ = γ ⊙ (R₁ − μ) / √(σ² + ε) + β",
                "Se calcula μ y σ sobre las coordenadas del token, se centra, se escala y se aplican γ y β.",
                block.conexion_atencion.norma, None, None, None, None, r1, n1,
            )
        if identifier == "ffn_expand":
            column = int(pre[:WIDE].abs().argmax().item())
            linear = ff.capa_expansion
            return _projection(
                f"H = N₁W₁ + b₁   ({int(n1.numel())} → {int(pre.numel())})",
                "Cada neurona oculta hace su propio producto punto con N₁; se muestra la más activa de las visibles.",
                f"N₁{ts}", n1,
                [_dot_output(n1, linear.weight[column], label="H", w_label=f"W₁[:,{column}]",
                             result_label=f"H[{column}]",
                             bias=linear.bias[column] if linear.bias is not None else None,
                             vector_values=pre, highlight=column)],
            )
        if identifier == "ffn_activation":
            return {
                "kind": "activation",
                "title": f"A = {activation}(H)",
                "caption": "La activación se aplica a cada coordenada por separado y dobla la recta: ahí está la no linealidad.",
                "name": activation,
                "inputs": _vec(pre, 12),
                "outputs": _vec(act, 12),
                "size": int(pre.numel()),
            }
        if identifier == "ffn_project":
            column = int(out[:WIDE].abs().argmax().item())
            linear = ff.capa_proyeccion
            return _projection(
                f"F = AW₂ + b₂   ({int(act.numel())} → {int(out.numel())})",
                "La proyección comprime d_ff de regreso a d_model para poder sumarse al residual.",
                f"A{ts}", act,
                [_dot_output(act, linear.weight[column], label="F", w_label=f"W₂[:,{column}]",
                             result_label=f"F[{column}]",
                             bias=linear.bias[column] if linear.bias is not None else None,
                             vector_values=out, highlight=column)],
            )
        if identifier == "norm_2":
            return _layer_norm(
                f"X_{layer + 1} = LN(N₁ + F)",
                "Segunda suma residual y normalización: la salida queda lista para la siguiente capa.",
                block.conexion_feed_forward.norma, "N₁", "F",
                second["entrada_visual"][0, t], second["actualizacion_visual"][0, t],
                second["antes_norma_visual"][0, t], second["salida_visual"][0, t],
            )
        if identifier == "stack":
            blocks = self.model.encoder.bloques
            states = [("X₀", blocks[0].conexion_atencion.ultima_traza["entrada_visual"][0, t])]
            for index, item in enumerate(blocks, start=1):
                states.append((f"X{self.sub(index)}", item.conexion_feed_forward.ultima_traza["salida_visual"][0, t]))
            return _stack(
                f"X_N = Encoder_{len(blocks)}(…Encoder₁(X₀))  ·  token «{labels[t]}»",
                "El mismo token sube piso por piso; su vector cambia en cada capa mientras conserva su posición.",
                labels[t], states,
            )
        return None

    # ------------------------------------------------------------- módulo 6
    def _module_6(self, identifier: str) -> dict[str, Any] | None:
        block = self.model.decoder.bloques[self.layer]
        target = self.prepared["target"]
        labels = self.target_labels()
        t = self.target_index()
        ts = self.sub(t)
        first = block.conexion_autoatencion.ultima_traza
        second = block.conexion_atencion_cruzada.ultima_traza
        third = block.conexion_feed_forward.ultima_traza
        causal = _square(self.prepared["selected_causal_mask"]).bool()
        if identifier == "decoder_prefix":
            objective = self.prepared.get("objective")
            return {
                "kind": "shift",
                "title": ("entrada = [BOS, y₀, …]  →  objetivo = [y₀, …, EOS]" if self.training
                          else f"prefijo_{t} = [" + ", ".join(labels) + "]"),
                "caption": ("La entrada es el objetivo desplazado una posición: en cada lugar se predice el siguiente token."
                            if self.training else
                            "En inferencia solo existe lo ya generado; la siguiente posición está vacía."),
                "training": self.training,
                "inputs": self.chips(target[0].tolist()),
                "targets": self.chips(objective[0].tolist()) if objective is not None else [],
                "highlight": t,
            }
        if identifier == "decoder_embedding":
            return _sum(
                f"Z₀[{t}] = E_out[{int(target[0, t])}]·√d + PE{ts}   («{labels[t]}»)",
                "El prefijo se convierte en vectores igual que la fuente: embedding escalado más posición.",
                "E_out·√d", f"PE{ts}", f"Z₀[{t}]",
                self.trace["embedding_decoder_escalado"][0, t],
                self.trace["posicion_decoder"][0, t],
                self.trace["entrada_decoder"][0, t],
            )
        if identifier == "causal_mask":
            counterfactual = not bool(self.ctx["causal_mask"])
            return {
                "kind": "causal_mask",
                "title": "M[i,j] = (j ≤ i)" if not counterfactual else "M[i,j] = 1  (contrafactual)",
                "caption": ("Cada fila es una posición que pregunta; solo puede mirar columnas de su presente y su pasado."
                            if not counterfactual else
                            "Con la máscara desactivada todas las posiciones ven el futuro: sirve solo como comparación."),
                "labels": labels,
                "mask": [[bool(v) for v in row] for row in causal.tolist()],
                "highlight": t,
                "causal": not counterfactual,
            }
        if identifier == "masked_attention":
            attention = block.autoatencion
            x = first["entrada_visual"]
            data = self._attention(attention, x, None, self.head)
            row = t
            note = "Las posiciones futuras reciben −∞ y, tras Softmax, peso exactamente cero."
            if bool(causal[row].all()) and len(labels) > 1 and not bool(causal.all()):
                # En inferencia la posición elegida es la última: nada queda en
                # su futuro. Una fila intermedia muestra pasado y futuro a la vez.
                row = (len(labels) - 1) // 2
                note = (f"La posición {t} es la última del prefijo y no tiene futuro que ocultar; "
                        f"la fila {row} muestra cómo se bloquea lo que viene después.")
            allowed = [bool(v) for v in causal[row].tolist()]
            return _softmax(
                f"A_self[{row},:] = softmax(mask(q{self.sub(row)}Kᵀ/√d))",
                note, labels, data["scaled"][self.head, row], allowed,
                attention.ultimos_pesos_atencion[0, self.head, row], labels[row],
            )
        if identifier == "decoder_residual_1":
            return _layer_norm(
                "N₁ = LN(Z + A_self)",
                "El estado del prefijo se conserva por el atajo y se suma el contexto causal antes de normalizar.",
                block.conexion_autoatencion.norma, "Z", "A_self",
                first["entrada_visual"][0, t], first["actualizacion_visual"][0, t],
                first["antes_norma_visual"][0, t], first["salida_visual"][0, t],
            )
        if identifier == "cross_attention":
            attention = block.atencion_cruzada
            memory = self.trace["salida_encoder"]
            data = self._attention(attention, second["entrada_visual"], memory, self.head)
            mask = self.prepared["encoder_mask"]
            source_labels = self.source_labels()
            allowed = ([bool(v) for v in _square(mask)[-1].tolist()]
                       if mask is not None else [True] * len(source_labels))
            return _softmax(
                f"A_cross[{t},:] = softmax(q{ts}·K_memᵀ/√d)",
                f"La query de «{labels[t]}» (decoder) se compara con las keys de la memoria del encoder.",
                source_labels, data["scaled"][self.head, t], allowed,
                attention.ultimos_pesos_atencion[0, self.head, t], labels[t],
            )
        if identifier == "decoder_residual_2":
            return _layer_norm(
                "N₂ = LN(N₁ + A_cross)",
                "Se suma lo recuperado de la fuente al estado del decoder y se normaliza.",
                block.conexion_atencion_cruzada.norma, "N₁", "A_cross",
                second["entrada_visual"][0, t], second["actualizacion_visual"][0, t],
                second["antes_norma_visual"][0, t], second["salida_visual"][0, t],
            )
        if identifier == "decoder_ffn":
            ff = block.feed_forward
            n2 = third["entrada_visual"][0, t]
            pre, act, out = self._ffn_parts(ff, n2)
            return {
                "kind": "ffn",
                "title": f"F = W₂ {ff.activacion.__class__.__name__}(W₁N₂ + b₁) + b₂",
                "caption": "Expansión a d_ff, no linealidad que recorta valores y compresión de vuelta a d_model.",
                "name": ff.activacion.__class__.__name__,
                "input": _vec(n2, WIDE),
                "pre": _vec(pre, WIDE * 2),
                "act": _vec(act, WIDE * 2),
                "output": _vec(out, WIDE),
                "d_model": int(n2.numel()),
                "d_ff": int(pre.numel()),
            }
        if identifier == "decoder_output":
            return _layer_norm(
                f"Z_{self.layer + 1} = LN(N₂ + F)",
                "Tercera suma residual: el resultado es la salida de esta capa del decoder.",
                block.conexion_feed_forward.norma, "N₂", "F",
                third["entrada_visual"][0, t], third["actualizacion_visual"][0, t],
                third["antes_norma_visual"][0, t], third["salida_visual"][0, t],
            )
        if identifier == "decoder_layers":
            blocks = self.model.decoder.bloques
            states = [("Z₀", blocks[0].conexion_autoatencion.ultima_traza["entrada_visual"][0, t])]
            for index, item in enumerate(blocks, start=1):
                states.append((f"Z{self.sub(index)}", item.conexion_feed_forward.ultima_traza["salida_visual"][0, t]))
            return _stack(
                f"Z_N = Decoder_{len(blocks)}(…Decoder₁(Z₀))  ·  posición {t}",
                "La misma posición del prefijo se refina capa por capa hasta el estado final.",
                labels[t], states,
            )
        return None

    # ------------------------------------------------------ salida (7 y 8)
    def _candidates(self, limit: int = VISIBLE) -> list[dict[str, Any]]:
        return list(self.ctx["candidates"])[:limit]

    def _logit_projection(self, title_prefix: str) -> dict[str, Any]:
        position = self.output_position()
        hidden = self.trace["salida_decoder"][0, position]
        linear = self.model.capa_salida
        selected = int(self.ctx["selected_id"])
        candidates = self._candidates()
        logits = self.ctx["raw_logits"][0]
        values = torch.tensor([float(logits[c["id"]]) for c in candidates])
        labels = [str(c["text"]) for c in candidates]
        highlight = next((index for index, c in enumerate(candidates) if c["id"] == selected), 0)
        output = _dot_output(
            hidden, linear.weight[selected], label="z",
            w_label=f"W_vocab[«{self.label(selected)}»]", result_label=f"z[{selected}]",
            bias=linear.bias[selected] if linear.bias is not None else None,
            vector_values=values, vector_labels=labels, highlight=highlight,
        )
        return _projection(
            f"{title_prefix}z[«{self.label(selected)}»] = h_t · W_vocab[{selected}] + b",
            f"Cada token del vocabulario ({int(self.config.tamano_vocabulario)}) hace este producto punto; "
            "se muestran los candidatos con mayor score.",
            "h_t", hidden, [output],
        )

    def _cross_entropy(self) -> dict[str, Any]:
        position = self.output_position()
        objective = self.prepared["objective"]
        target_id = int(objective[0, position].item())
        logits = self.ctx["logits"][0, position].detach().float()
        log_probs = F.log_softmax(logits, dim=-1)
        probs = log_probs.exp()
        order = torch.argsort(probs, descending=True)[:6].tolist()
        if target_id not in order:
            order = order[:5] + [target_id]
        p_target = float(probs[target_id].item())
        return {
            "kind": "cross_entropy",
            "title": f"L = −log p(«{self.label(target_id)}») = −log {p_target:.4f} = {-float(log_probs[target_id]):.4f}",
            "caption": "Softmax convierte los logits en probabilidades y la pérdida mira solo la del token correcto.",
            "items": [
                {"text": self.label(token), "id": int(token),
                 "logit": _num(logits[token].item()), "prob": _num(probs[token].item()),
                 "target": int(token) == target_id}
                for token in order
            ],
            "target": {"text": self.label(target_id), "id": target_id, "prob": _num(p_target)},
            "loss": _num(-float(log_probs[target_id].item())),
            "position": position,
            "vocabulary": int(logits.numel()),
        }

    def _sampling(self, stages: list[str]) -> dict[str, Any]:
        raw = self.ctx["raw_logits"][0].float()
        adjusted = self.ctx["adjusted"][0].float()
        after_k = self.ctx["after_k"][0].float()
        probabilities = self.ctx["probabilities"][0].float()
        temperature = max(0.01, float(self.ctx["temperature"]))
        top_k = max(1, min(int(self.ctx["top_k"]), raw.numel()))
        top_p = max(0.01, min(float(self.ctx["top_p"]), 1.0))
        prob_raw = F.softmax(raw, dim=-1)
        prob_t = F.softmax(adjusted, dim=-1)
        prob_k = F.softmax(after_k, dim=-1)
        order = torch.argsort(adjusted, descending=True)[:10].tolist()
        cumulative = 0.0
        items = []
        for token in order:
            kept_k = bool(torch.isfinite(after_k[token]).item())
            cumulative += float(prob_k[token].item()) if kept_k else 0.0
            items.append({
                "text": self.label(token),
                "id": int(token),
                "logit": _num(raw[token].item()),
                "scaled": _num(adjusted[token].item()),
                "prob_raw": _num(prob_raw[token].item()),
                "prob_t": _num(prob_t[token].item()),
                "kept_k": kept_k,
                "prob_k": _num(prob_k[token].item()),
                "cumulative": _num(cumulative),
                "kept_p": bool(probabilities[token].item() > 0),
                "final": _num(probabilities[token].item()),
            })
        survivors_k = int(torch.isfinite(after_k).sum().item())
        survivors_p = int((probabilities > 0).sum().item())
        parts = []
        if "temperature" in stages:
            parts.append(f"z/T con T = {temperature:.2f}")
        if "top_k" in stages:
            parts.append(f"Top-K = {top_k} → {survivors_k} quedan")
        if "top_p" in stages:
            parts.append(f"Top-P = {top_p:.2f} → {survivors_p} quedan")
        captions = {
            "temperature": "Dividir entre T cambia la distancia entre logits: T<1 concentra la probabilidad y T>1 la reparte.",
            "top_k": "Se ordenan los logits y solo los K mayores siguen en competencia; el resto pasa a −∞.",
            "top_p": "Se acumula la probabilidad de los candidatos ordenados hasta alcanzar P; los demás se descartan.",
        }
        return {
            "kind": "sampling",
            "title": "  ·  ".join(parts),
            "caption": " ".join(captions[stage] for stage in stages),
            "stages": stages,
            "temperature": _num(temperature),
            "top_k": top_k,
            "top_p": _num(top_p),
            "items": items,
            "survivors_k": survivors_k,
            "survivors_p": survivors_p,
            "vocabulary": int(raw.numel()),
        }

    def _final_softmax(self) -> dict[str, Any]:
        filtered = self.ctx["filtered"][0].float()
        probabilities = self.ctx["probabilities"][0].float()
        order = [token for token in torch.argsort(filtered, descending=True).tolist()
                 if math.isfinite(float(filtered[token]))]
        shown = order[:VISIBLE]
        rest = order[VISIBLE:]
        rest_exp = sum(math.exp(float(filtered[token])) for token in rest)
        labels = [self.label(token) for token in shown]
        return _softmax(
            "p = softmax(z_filtrado)",
            f"Solo compiten los {len(order)} logits que sobrevivieron a los filtros; sus probabilidades suman 1.",
            labels, filtered[shown], [True] * len(shown), probabilities[shown], "z",
            rest={"count": len(rest), "exp_sum": rest_exp,
                  "prob": float(probabilities[rest].sum().item()) if rest else 0.0},
        )

    def _argmax(self) -> dict[str, Any]:
        candidates = self._candidates()
        chosen = next((index for index, c in enumerate(candidates) if c.get("chosen")), 0)
        selected = candidates[chosen] if candidates else {"text": "", "probability": 0}
        return {
            "kind": "argmax",
            "title": f"ŷ_t = argmax(p) = «{selected['text']}»  (p = {float(selected['probability']):.4f})",
            "caption": "Se recorren las probabilidades y gana la mayor; la elección es reproducible.",
            "items": [{"text": c["text"], "id": c["id"], "prob": c["probability"]} for c in candidates],
            "chosen": chosen,
        }

    def _append(self) -> dict[str, Any]:
        prefix = self.prepared["target"][0].tolist()
        selected = int(self.ctx["selected_id"])
        return {
            "kind": "append",
            "title": "prefijo ← [" + ", ".join(self.label(i) for i in prefix) + f"] ⊕ «{self.label(selected)}»",
            "caption": "El token elegido se anexa al final y el decoder vuelve a ejecutarse con un prefijo más largo.",
            "prefix": self.chips(prefix),
            "token": {"text": self.label(selected), "id": selected},
        }

    def _module_7(self, identifier: str) -> dict[str, Any] | None:
        position = self.output_position()
        hidden = self.trace["salida_decoder"][0, position]
        if identifier == "hidden":
            return {
                "kind": "vector",
                "title": f"h_{position} ∈ ℝ^{int(hidden.numel())}   ‖h‖ = {float(hidden.norm()):.4f}",
                "caption": "El estado final del decoder en la posición que predice: d_model números que resumen el contexto.",
                "label": f"h_{position}",
                "values": _vec(hidden, 32),
                "size": int(hidden.numel()),
                "norm": _num(hidden.norm().item()),
            }
        if identifier == "linear":
            return self._logit_projection("")
        if identifier == "target":
            objective = self.prepared.get("objective")
            return {
                "kind": "shift",
                "title": f"y_{position} = «{self.label(int(objective[0, position]))}»" if objective is not None else "y_t",
                "caption": "Teacher forcing: en la posición t entra el token anterior y el objetivo es el token correcto siguiente.",
                "training": True,
                "inputs": self.chips(self.prepared["target"][0].tolist()),
                "targets": self.chips(objective[0].tolist()) if objective is not None else [],
                "highlight": position,
            }
        if identifier == "loss":
            return self._cross_entropy()
        if identifier in {"temperature", "top_k", "top_p"}:
            return self._sampling([identifier])
        if identifier == "softmax":
            return self._final_softmax()
        if identifier == "select":
            return self._argmax()
        if identifier == "feedback":
            return self._append()
        return None

    def _module_8(self, identifier: str) -> dict[str, Any] | None:
        source_ids = list(self.prepared["source_ids"])
        index = self.source_index()
        if identifier == "full_tokens":
            pieces = [{"text": self.label(i), "id": int(i), "position": p} for p, i in enumerate(source_ids)]
            return {
                "kind": "lookup_ids",
                "title": "texto → [" + ", ".join(str(i) for i in source_ids) + "]",
                "caption": "El prompt se corta en tokens y cada uno se cambia por su ID del vocabulario.",
                "pieces": pieces,
                "vocabulary": int(self.config.tamano_vocabulario),
            }
        if identifier == "full_batch":
            objective = self.prepared.get("objective")
            return {
                "kind": "shift",
                "title": "(src, tgt_in, tgt_out)",
                "caption": "src entra al encoder; tgt_in (desplazado con BOS) al decoder; tgt_out es lo que debe predecirse.",
                "training": True,
                "source": self.chips(self.prepared["source"][0].tolist()),
                "inputs": self.chips(self.prepared["target"][0].tolist()),
                "targets": self.chips(objective[0].tolist()) if objective is not None else [],
                "highlight": self.target_index(),
            }
        if identifier == "full_embedding":
            label = self.label(source_ids[index]) if index < len(source_ids) else ""
            return _sum(
                f"x{self.sub(index)} = E[{int(self.prepared['source'][0, index])}]·√d + PE{self.sub(index)}   («{label}»)",
                "Cada ID se vuelve un vector: su fila de embedding escalada más la codificación de su posición.",
                "E·√d", f"PE{self.sub(index)}", f"x{self.sub(index)}",
                self.trace["embedding_encoder_escalado"][0, index],
                self.trace["posicion_encoder"][0, index],
                self.trace["entrada_encoder"][0, index],
            )
        if identifier == "full_encoder":
            blocks = self.model.encoder.bloques
            label = self.source_labels()[index]
            states = [("X₀", blocks[0].conexion_atencion.ultima_traza["entrada_visual"][0, index])]
            for number, item in enumerate(blocks, start=1):
                states.append((f"X{self.sub(number)}", item.conexion_feed_forward.ultima_traza["salida_visual"][0, index]))
            return _stack(
                f"Mem = Encoder(X)  ·  {len(blocks)} capas  ·  token «{label}»",
                "Cada capa del encoder reescribe el vector del token; la última salida es la memoria.",
                label, states,
            )
        if identifier == "full_decoder":
            blocks = self.model.decoder.bloques
            t = self.target_index() if self.training else self.prepared["target"].size(1) - 1
            label = self.target_labels()[t]
            states = [("Z₀", blocks[0].conexion_autoatencion.ultima_traza["entrada_visual"][0, t])]
            for number, item in enumerate(blocks, start=1):
                states.append((f"Z{self.sub(number)}", item.conexion_feed_forward.ultima_traza["salida_visual"][0, t]))
            return _stack(
                f"H_t = Decoder(prefijo, Mem)  ·  posición {t} («{label}»)",
                "El decoder combina el prefijo con la memoria en cada capa hasta producir el estado h_t.",
                label, states,
            )
        if identifier == "full_logits":
            return self._logit_projection("")
        if identifier == "full_filters":
            return self._sampling(["temperature", "top_k", "top_p"])
        if identifier == "full_select":
            return self._argmax()
        if identifier == "full_feedback":
            return self._append()
        if identifier == "full_loss":
            return self._cross_entropy()
        return None


def build_formula_demos(
    module_id: str,
    steps: list[dict[str, Any]],
    ctx: dict[str, Any],
    token_text: Callable[[Any, int], str],
) -> dict[str, Any]:
    """Punto de entrada usado por el controlador del laboratorio."""
    return FormulaDemoBuilder(ctx, token_text).build(module_id, steps)
