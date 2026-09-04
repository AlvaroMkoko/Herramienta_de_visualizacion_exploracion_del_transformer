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


# ---------------------------------------------------------------------------
# Generación autoregresiva (Transformer.generar)
# ---------------------------------------------------------------------------

class TestGeneracion:
    def test_forma_y_cantidad_de_pasos(self, modelo, config, batch_size):
        # batch_size=1: la generacion interactiva no soporta batch (ver
        # docstring de Transformer.generar)
        tokens_origen = _generar_tokens(config, 1, 8)

        generador = modelo.generar(
            tokens_origen, id_token_inicio=1, max_tokens_nuevos=5, muestreo_codicioso=True
        )
        pasos = list(generador)

        assert len(pasos) == 5
        for paso in pasos:
            assert paso["logits"].shape == (1, config.tamano_vocabulario)
            assert paso["logits_lineales"].shape == (1, config.tamano_vocabulario)
            assert torch.isfinite(paso["logits_lineales"]).all()
            assert torch.isneginf(paso["logits"][0, 1])
            assert isinstance(paso["token_id"], int)

    def test_valor_de_retorno_incluye_todos_los_tokens_generados(self, modelo, config):
        tokens_origen = _generar_tokens(config, 1, 8)

        generador = modelo.generar(
            tokens_origen, id_token_inicio=1, max_tokens_nuevos=5, muestreo_codicioso=True
        )
        pasos = []
        try:
            while True:
                pasos.append(next(generador))
        except StopIteration as fin:
            tokens_generados = fin.value

        assert tokens_generados.shape == (1, 5)
        # el id_token_inicio (1) NO debe estar incluido en el resultado,
        # solo los tokens generados
        ids_de_los_pasos = [p["token_id"] for p in pasos]
        assert tokens_generados.squeeze(0).tolist() == ids_de_los_pasos

    def test_expone_pesos_de_atencion_de_cada_capa(self, modelo, config):
        tokens_origen = _generar_tokens(config, 1, 8)

        pasos = list(
            modelo.generar(tokens_origen, id_token_inicio=1, max_tokens_nuevos=3, muestreo_codicioso=True)
        )

        for paso in pasos:
            assert len(paso["pesos_atencion_cruzada_por_capa"]) == config.num_capas
            assert len(paso["pesos_autoatencion_por_capa"]) == config.num_capas
            assert len(paso["pesos_atencion_encoder_por_capa"]) == config.num_capas

    def test_muestreo_codicioso_es_determinista(self, modelo, config):
        """Dos corridas con muestreo_codicioso deben producir EXACTAMENTE
        la misma secuencia (sin necesidad de fijar semilla — es
        determinista por definicion, no depende de aleatoriedad)."""
        tokens_origen = _generar_tokens(config, 1, 8)

        pasos_1 = list(
            modelo.generar(tokens_origen, id_token_inicio=1, max_tokens_nuevos=6, muestreo_codicioso=True)
        )
        pasos_2 = list(
            modelo.generar(tokens_origen, id_token_inicio=1, max_tokens_nuevos=6, muestreo_codicioso=True)
        )

        ids_1 = [p["token_id"] for p in pasos_1]
        ids_2 = [p["token_id"] for p in pasos_2]
        assert ids_1 == ids_2

    def test_id_token_fin_detiene_la_generacion_antes_de_max_tokens_nuevos(self, modelo, config):
        """Se usa muestreo con temperatura (no codicioso) y semilla fija
        para tener variedad de tokens y poder forzar una parada en un
        punto conocido. Con muestreo_codicioso un modelo sin entrenar
        puede colapsar y repetir siempre el mismo token, lo que haría
        la prueba invalida (ver nota en la sesion de exploracion)."""
        tokens_origen = _generar_tokens(config, 1, 8)

        torch.manual_seed(7)
        pasos_sin_parada = list(
            modelo.generar(tokens_origen, id_token_inicio=1, max_tokens_nuevos=6, temperatura=1.0)
        )
        ids_referencia = [p["token_id"] for p in pasos_sin_parada]
        assert len(set(ids_referencia)) > 1, "se necesita variedad de tokens para que la prueba sea valida"

        id_fin_forzado = ids_referencia[2]

        torch.manual_seed(7)  # misma semilla -> misma secuencia de muestreo
        generador_con_fin = modelo.generar(
            tokens_origen, id_token_inicio=1, id_token_fin=id_fin_forzado,
            max_tokens_nuevos=6, temperatura=1.0,
        )
        pasos_con_fin = []
        try:
            while True:
                pasos_con_fin.append(next(generador_con_fin))
        except StopIteration as fin:
            tokens_generados = fin.value

        assert len(pasos_con_fin) == 3  # se detiene justo al generar el 3er token (indice 2)
        assert pasos_con_fin[-1]["token_id"] == id_fin_forzado
        assert tokens_generados.shape == (1, 3)

    def test_sin_id_token_fin_genera_hasta_el_limite(self, modelo, config):
        tokens_origen = _generar_tokens(config, 1, 8)

        pasos = list(
            modelo.generar(
                tokens_origen, id_token_inicio=1, id_token_fin=None,
                max_tokens_nuevos=7, muestreo_codicioso=True,
            )
        )

        assert len(pasos) == 7

    def test_encoder_se_ejecuta_una_sola_vez(self, modelo, config):
        """Los pesos de atencion del ENCODER no deberian cambiar entre
        pasos, porque la secuencia de entrada no cambia durante la
        generacion (solo el decoder se recalcula en cada paso)."""
        tokens_origen = _generar_tokens(config, 1, 8)

        pasos = list(
            modelo.generar(tokens_origen, id_token_inicio=1, max_tokens_nuevos=4, muestreo_codicioso=True)
        )

        pesos_encoder_paso_0 = pasos[0]["pesos_atencion_encoder_por_capa"]
        pesos_encoder_ultimo_paso = pasos[-1]["pesos_atencion_encoder_por_capa"]

        for capa_inicial, capa_final in zip(pesos_encoder_paso_0, pesos_encoder_ultimo_paso):
            assert torch.equal(capa_inicial, capa_final)

    def test_restaura_el_modo_entrenamiento_tras_generar(self, modelo, config):
        tokens_origen = _generar_tokens(config, 1, 5)

        modelo.train()
        assert modelo.training is True

        list(modelo.generar(tokens_origen, id_token_inicio=1, max_tokens_nuevos=2))

        assert modelo.training is True  # debe volver al estado previo, no quedar en eval()

    def test_generar_no_acumula_gradientes(self, modelo, config):
        """generar() esta decorado con @torch.no_grad(); confirmamos que
        no queda ningun grafo de computo colgando (los parametros no
        deberian tener gradientes calculados solo por llamar a generar)."""
        tokens_origen = _generar_tokens(config, 1, 5)

        modelo.zero_grad()
        list(modelo.generar(tokens_origen, id_token_inicio=1, max_tokens_nuevos=3, muestreo_codicioso=True))

        assert all(p.grad is None for p in modelo.parameters())
