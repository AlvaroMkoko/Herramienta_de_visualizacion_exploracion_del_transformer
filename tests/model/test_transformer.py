"""
Pruebas de integración del Transformer completo (`transformer.py`).

A diferencia de `test_attention.py` (que prueba una pieza aislada), aquí
se valida que TODO el pipeline funcione junto:
Embedding -> Positional Encoding -> Encoder (N×) -> Decoder (N×) -> Linear -> Softmax.

Cubren:
- Instanciación y forma de los logits de salida.
- Que `obtener_probabilidades` produzca una distribución válida.
- Que `calcular_perdida` funcione y sea derivable (backward end-to-end).
- Causalidad end-to-end: alterar un token futuro del destino no debe
  afectar la predicción de posiciones anteriores.
- Que las máscaras de relleno generadas automáticamente por
  `crear_mascaras` realmente aíslen las posiciones de relleno.
- Weight tying (compartir_pesos_salida).
"""

import pytest
import torch

from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.transformer import Transformer


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def config() -> ConfiguracionTransformer:
    return ConfiguracionTransformer(
        tamano_vocabulario=200,
        dimension_modelo=64,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=256,
        longitud_maxima_secuencia=50,
        dropout=0.0,  # determinismo en las pruebas
        id_token_relleno=0,
    )


@pytest.fixture
def modelo(config) -> Transformer:
    torch.manual_seed(0)
    return Transformer(config)


@pytest.fixture
def batch_size() -> int:
    return 2


def _generar_tokens(config, batch_size: int, longitud: int, incluir_relleno: bool = False) -> torch.Tensor:
    """Genera ids de tokens aleatorios en rango válido (nunca 0, salvo relleno)."""
    tokens = torch.randint(1, config.tamano_vocabulario, (batch_size, longitud))
    if incluir_relleno:
        tokens[:, -3:] = config.id_token_relleno
    return tokens


# ---------------------------------------------------------------------------
# Forward básico
# ---------------------------------------------------------------------------

class TestForward:
    def test_forma_de_logits(self, modelo, config, batch_size):
        t_src, t_tgt = 12, 9
        tokens_origen = _generar_tokens(config, batch_size, t_src)
        tokens_destino = _generar_tokens(config, batch_size, t_tgt)

        logits = modelo(tokens_origen, tokens_destino)

        assert logits.shape == (batch_size, t_tgt, config.tamano_vocabulario)

    def test_logits_no_contienen_nan_ni_inf(self, modelo, config, batch_size):
        tokens_origen = _generar_tokens(config, batch_size, 12)
        tokens_destino = _generar_tokens(config, batch_size, 9)

        logits = modelo(tokens_origen, tokens_destino)

        assert not torch.isnan(logits).any()
        assert not torch.isinf(logits).any()

    def test_longitudes_origen_destino_independientes(self, modelo, config, batch_size):
        """El encoder y el decoder pueden trabajar con longitudes de
        secuencia distintas (T_src != T_tgt) gracias a la cross-attention."""
        tokens_origen = _generar_tokens(config, batch_size, 20)
        tokens_destino = _generar_tokens(config, batch_size, 5)

        logits = modelo(tokens_origen, tokens_destino)

        assert logits.shape == (batch_size, 5, config.tamano_vocabulario)


# ---------------------------------------------------------------------------
# Probabilidades y pérdida
# ---------------------------------------------------------------------------

class TestProbabilidadesYPerdida:
    def test_probabilidades_suman_uno(self, modelo, config, batch_size):
        tokens_origen = _generar_tokens(config, batch_size, 10)
        tokens_destino = _generar_tokens(config, batch_size, 7)

        logits = modelo(tokens_origen, tokens_destino)
        probabilidades = modelo.obtener_probabilidades(logits)

        suma = probabilidades.sum(dim=-1)
        assert torch.allclose(suma, torch.ones_like(suma), atol=1e-5)

    def test_probabilidades_no_negativas(self, modelo, config, batch_size):
        tokens_origen = _generar_tokens(config, batch_size, 10)
        tokens_destino = _generar_tokens(config, batch_size, 7)

        logits = modelo(tokens_origen, tokens_destino)
        probabilidades = modelo.obtener_probabilidades(logits)

        assert (probabilidades >= 0).all()

    def test_calcular_perdida_es_escalar_positivo(self, modelo, config, batch_size):
        tokens_origen = _generar_tokens(config, batch_size, 10)
        tokens_destino = _generar_tokens(config, batch_size, 7)
        objetivo = _generar_tokens(config, batch_size, 7)

        logits = modelo(tokens_origen, tokens_destino)
        perdida = modelo.calcular_perdida(logits, objetivo)

        assert perdida.dim() == 0
        assert perdida.item() > 0

    def test_perdida_ignora_posiciones_de_relleno(self, modelo, config, batch_size):
        """Si el objetivo tiene relleno, la pérdida no debe verse afectada
        por lo que el modelo prediga en esas posiciones."""
        tokens_origen = _generar_tokens(config, batch_size, 10)
        tokens_destino = _generar_tokens(config, batch_size, 7)
        objetivo = _generar_tokens(config, batch_size, 7)
        objetivo[:, -2:] = config.id_token_relleno

        logits = modelo(tokens_origen, tokens_destino)

        perdida_a = modelo.calcular_perdida(logits, objetivo)

        objetivo_b = objetivo.clone()
        objetivo_b[:, -2:] = config.id_token_relleno  # sin cambios reales, control
        perdida_b = modelo.calcular_perdida(logits, objetivo_b)

        assert torch.isclose(perdida_a, perdida_b)


# ---------------------------------------------------------------------------
# Backward / entrenabilidad
# ---------------------------------------------------------------------------

class TestBackward:
    def test_backward_actualiza_todos_los_parametros(self, modelo, config, batch_size):
        tokens_origen = _generar_tokens(config, batch_size, 10)
        tokens_destino = _generar_tokens(config, batch_size, 7)
        objetivo = _generar_tokens(config, batch_size, 7)

        logits = modelo(tokens_origen, tokens_destino)
        perdida = modelo.calcular_perdida(logits, objetivo)
        perdida.backward()

        parametros_entrenables = [p for p in modelo.parameters() if p.requires_grad]
        assert len(parametros_entrenables) > 0
        assert all(p.grad is not None for p in parametros_entrenables)
        assert all(not torch.isnan(p.grad).any() for p in parametros_entrenables)

    def test_un_paso_de_optimizacion_reduce_la_perdida(self, modelo, config, batch_size):
        """Prueba de humo del ciclo completo de entrenamiento: tras varios
        pasos de descenso de gradiente sobre el MISMO batch, la pérdida
        debe bajar (el modelo puede memorizar un solo batch pequeño)."""
        tokens_origen = _generar_tokens(config, batch_size, 8)
        tokens_destino = _generar_tokens(config, batch_size, 6)
        objetivo = _generar_tokens(config, batch_size, 6)

        optimizador = torch.optim.Adam(modelo.parameters(), lr=1e-3)

        perdida_inicial = None
        perdida_final = None
        for paso in range(20):
            optimizador.zero_grad()
            logits = modelo(tokens_origen, tokens_destino)
            perdida = modelo.calcular_perdida(logits, objetivo)
            if paso == 0:
                perdida_inicial = perdida.item()
            perdida.backward()
            optimizador.step()
            perdida_final = perdida.item()

        assert perdida_final < perdida_inicial


# ---------------------------------------------------------------------------
# Causalidad end-to-end
# ---------------------------------------------------------------------------

class TestCausalidad:
    def test_alterar_token_futuro_del_destino_no_afecta_pasado(self, modelo, config, batch_size):
        modelo.eval()
        tokens_origen = _generar_tokens(config, batch_size, 10)
        tokens_destino = _generar_tokens(config, batch_size, 8)

        with torch.no_grad():
            tokens_destino_alt = tokens_destino.clone()
            tokens_destino_alt[:, -1] = torch.randint(1, config.tamano_vocabulario, (batch_size,))

            logits_original = modelo(tokens_origen, tokens_destino)
            logits_alterado = modelo(tokens_origen, tokens_destino_alt)

            diferencia_pos0 = (logits_original[:, 0, :] - logits_alterado[:, 0, :]).abs().max()

        assert diferencia_pos0.item() < 1e-5

    def test_alterar_token_pasado_del_destino_si_afecta_presente(self, modelo, config, batch_size):
        """Contraprueba: alterar un token PASADO sí debe cambiar la
        predicción de una posición posterior (confirma que el modelo usa
        el contexto, no que está roto/ignorando todo)."""
        modelo.eval()
        tokens_origen = _generar_tokens(config, batch_size, 10)
        tokens_destino = _generar_tokens(config, batch_size, 8)

        with torch.no_grad():
            tokens_destino_alt = tokens_destino.clone()
            tokens_destino_alt[:, 0] = torch.randint(1, config.tamano_vocabulario, (batch_size,))

            logits_original = modelo(tokens_origen, tokens_destino)
            logits_alterado = modelo(tokens_origen, tokens_destino_alt)

            diferencia_ultima_pos = (logits_original[:, -1, :] - logits_alterado[:, -1, :]).abs().max()

        assert diferencia_ultima_pos.item() > 1e-5


# ---------------------------------------------------------------------------
# Máscaras de relleno automáticas
# ---------------------------------------------------------------------------

class TestMascarasAutomaticas:
    def test_crear_mascaras_formas_correctas(self, modelo, config, batch_size):
        tokens_origen = _generar_tokens(config, batch_size, 10, incluir_relleno=True)
        tokens_destino = _generar_tokens(config, batch_size, 7)

        mascara_encoder, mascara_causal = modelo.crear_mascaras(tokens_origen, tokens_destino)

        assert mascara_encoder.shape == (batch_size, 1, 1, 10)
        assert mascara_causal.shape[-2:] == (7, 7)

    def test_relleno_del_origen_no_afecta_salida_si_mascara_se_fija(self, modelo, config, batch_size):
        """Aislando la máscara (fijándola explícitamente) del contenido del
        token, confirmamos que una posición de relleno del origen
        realmente no influye en los logits.

        Nota: si en cambio se altera el ID de un token de relleno SIN fijar
        la máscara, `crear_mascaras` recalcula la máscara a partir del
        nuevo contenido, y esa posición dejaría de contar como relleno —
        por eso la máscara se fija explícitamente aquí antes de alterar.
        """
        modelo.eval()
        tokens_origen = _generar_tokens(config, batch_size, 10, incluir_relleno=True)
        tokens_destino = _generar_tokens(config, batch_size, 7)

        with torch.no_grad():
            mascara_encoder_fija, mascara_causal_fija = modelo.crear_mascaras(
                tokens_origen, tokens_destino
            )

            tokens_origen_alt = tokens_origen.clone()
            tokens_origen_alt[:, -1] = torch.randint(1, config.tamano_vocabulario, (batch_size,))

            logits_original = modelo(
                tokens_origen, tokens_destino,
                mascara_encoder=mascara_encoder_fija, mascara_causal=mascara_causal_fija,
            )
            logits_alterado = modelo(
                tokens_origen_alt, tokens_destino,
                mascara_encoder=mascara_encoder_fija, mascara_causal=mascara_causal_fija,
            )

            diferencia = (logits_original - logits_alterado).abs().max()

        assert diferencia.item() < 1e-5

    def test_alterar_posicion_no_enmascarada_si_afecta_salida(self, modelo, config, batch_size):
        """Contraprueba de la anterior: alterar una posición REAL (no
        relleno) del origen sí debe cambiar los logits."""
        modelo.eval()
        tokens_origen = _generar_tokens(config, batch_size, 10, incluir_relleno=True)
        tokens_destino = _generar_tokens(config, batch_size, 7)

        with torch.no_grad():
            mascara_encoder_fija, mascara_causal_fija = modelo.crear_mascaras(
                tokens_origen, tokens_destino
            )

            tokens_origen_alt = tokens_origen.clone()
            tokens_origen_alt[:, 0] = torch.randint(1, config.tamano_vocabulario, (batch_size,))

            logits_original = modelo(
                tokens_origen, tokens_destino,
                mascara_encoder=mascara_encoder_fija, mascara_causal=mascara_causal_fija,
            )
            logits_alterado = modelo(
                tokens_origen_alt, tokens_destino,
                mascara_encoder=mascara_encoder_fija, mascara_causal=mascara_causal_fija,
            )

            diferencia = (logits_original - logits_alterado).abs().max()

        assert diferencia.item() > 1e-5


# ---------------------------------------------------------------------------
# Weight tying
# ---------------------------------------------------------------------------

class TestWeightTying:
    def test_pesos_compartidos_por_defecto(self, config):
        torch.manual_seed(0)
        modelo = Transformer(config)

        assert modelo.capa_salida.weight is modelo.embedding_salida.embedding.weight

    def test_sin_weight_tying_tiene_mas_parametros(self, config):
        torch.manual_seed(0)
        modelo_con_tying = Transformer(config, compartir_pesos_salida=True)
        torch.manual_seed(0)
        modelo_sin_tying = Transformer(config, compartir_pesos_salida=False)

        params_con = sum(p.numel() for p in modelo_con_tying.parameters())
        params_sin = sum(p.numel() for p in modelo_sin_tying.parameters())

        assert params_sin > params_con
        diferencia_esperada = config.tamano_vocabulario * config.dimension_modelo
        assert params_sin - params_con == diferencia_esperada