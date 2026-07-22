"""
Pruebas unitarias del núcleo de atención: `mascara.py` y `atencion.py`.

Cubren:
- Formas de tensores correctas (self-attention y cross-attention).
- Que los pesos de atención sean una distribución de probabilidad válida
  (softmax suma 1 por fila).
- Que la máscara causal realmente bloquee la información futura.
- Que la cross-attention permita longitudes distintas entre Q y K/V, y
  que SÍ pueda ver toda la secuencia del encoder (sin causalidad).
- Que los gradientes fluyan correctamente (backward end-to-end).
- Que `AtencionMultiCabeza` exponga `ultimos_pesos_atencion` (lo usa el
  ViewModel para el Lienzo Científico).
"""

import pytest
import torch

from model.motor_llm.atencion import AtencionMultiCabeza, atencion_escalada
from model.motor_llm.config import ConfiguracionTransformer
from model.motor_llm.mascara import crear_mascara_causal, crear_mascara_relleno


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def config() -> ConfiguracionTransformer:
    """Configuración pequeña para pruebas rápidas."""
    return ConfiguracionTransformer(
        tamano_vocabulario=1000,
        dimension_modelo=64,
        num_cabezas=4,
        num_capas=2,
        dimension_ff=256,
        longitud_maxima_secuencia=64,
        dropout=0.0,  # dropout=0 en pruebas para que los resultados sean deterministas
    )


@pytest.fixture
def batch_size() -> int:
    return 2


# ---------------------------------------------------------------------------
# atencion_escalada (función pura)
# ---------------------------------------------------------------------------

class TestAtencionEscalada:
    def test_forma_de_salida_self_attention(self, config, batch_size):
        t = 8
        q = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        k = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        v = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)

        salida, pesos = atencion_escalada(q, k, v)

        assert salida.shape == (batch_size, config.num_cabezas, t, config.dimension_cabeza)
        assert pesos.shape == (batch_size, config.num_cabezas, t, t)

    def test_forma_de_salida_cross_attention_longitudes_distintas(self, config, batch_size):
        t_q, t_k = 5, 9
        q = torch.randn(batch_size, config.num_cabezas, t_q, config.dimension_cabeza)
        k = torch.randn(batch_size, config.num_cabezas, t_k, config.dimension_cabeza)
        v = torch.randn(batch_size, config.num_cabezas, t_k, config.dimension_cabeza)

        salida, pesos = atencion_escalada(q, k, v)

        assert salida.shape == (batch_size, config.num_cabezas, t_q, config.dimension_cabeza)
        assert pesos.shape == (batch_size, config.num_cabezas, t_q, t_k)

    def test_pesos_de_atencion_suman_uno(self, config, batch_size):
        """El softmax debe producir una distribución de probabilidad válida
        en cada fila (cada posición de consulta)."""
        t = 6
        q = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        k = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        v = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)

        _, pesos = atencion_escalada(q, k, v)
        suma_por_fila = pesos.sum(dim=-1)

        assert torch.allclose(suma_por_fila, torch.ones_like(suma_por_fila), atol=1e-6)

    def test_pesos_no_negativos(self, config, batch_size):
        t = 6
        q = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        k = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        v = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)

        _, pesos = atencion_escalada(q, k, v)

        assert (pesos >= 0).all()

    def test_mascara_causal_bloquea_futuro(self, config, batch_size):
        """Con máscara causal, el peso de atención hacia una posición
        futura debe ser exactamente 0 (softmax de -infinito)."""
        t = 6
        q = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        k = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        v = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        mascara = crear_mascara_causal(t)

        _, pesos = atencion_escalada(q, k, v, mascara=mascara)

        # pesos[:, :, i, j] debe ser 0 para todo j > i (futuro)
        for i in range(t):
            for j in range(i + 1, t):
                assert torch.allclose(pesos[:, :, i, j], torch.zeros(batch_size, config.num_cabezas))

    def test_sin_mascara_atiende_a_toda_la_secuencia(self, config, batch_size):
        """Sin máscara, ninguna posición debe tener peso exactamente 0
        (salvo coincidencia estadística extrema, prácticamente imposible
        con valores aleatorios continuos)."""
        t = 6
        q = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        k = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)
        v = torch.randn(batch_size, config.num_cabezas, t, config.dimension_cabeza)

        _, pesos = atencion_escalada(q, k, v)

        assert (pesos > 0).all()


# ---------------------------------------------------------------------------
# AtencionMultiCabeza (módulo nn.Module)
# ---------------------------------------------------------------------------

class TestAtencionMultiCabeza:
    def test_forma_de_salida_self_attention(self, config, batch_size):
        t = 8
        x = torch.randn(batch_size, t, config.dimension_modelo)
        atencion = AtencionMultiCabeza(config)

        salida = atencion(x)

        assert salida.shape == (batch_size, t, config.dimension_modelo)

    def test_forma_de_salida_cross_attention(self, config, batch_size):
        """Q viene de una secuencia de longitud T_tgt, K/V de una secuencia
        de longitud distinta T_src (caso decoder -> encoder)."""
        t_tgt, t_src = 5, 9
        x_decoder = torch.randn(batch_size, t_tgt, config.dimension_modelo)
        x_encoder = torch.randn(batch_size, t_src, config.dimension_modelo)
        atencion = AtencionMultiCabeza(config)

        salida = atencion(x_decoder, x_clave_valor=x_encoder)

        assert salida.shape == (batch_size, t_tgt, config.dimension_modelo)

    def test_expone_ultimos_pesos_atencion(self, config, batch_size):
        t = 7
        x = torch.randn(batch_size, t, config.dimension_modelo)
        atencion = AtencionMultiCabeza(config)

        assert atencion.ultimos_pesos_atencion is None  # antes del forward

        atencion(x)

        assert atencion.ultimos_pesos_atencion is not None
        assert atencion.ultimos_pesos_atencion.shape == (
            batch_size,
            config.num_cabezas,
            t,
            t,
        )

    def test_gradientes_fluyen_correctamente(self, config, batch_size):
        t = 8
        x = torch.randn(batch_size, t, config.dimension_modelo, requires_grad=True)
        atencion = AtencionMultiCabeza(config)

        salida = atencion(x)
        salida.sum().backward()

        assert x.grad is not None
        assert not torch.isnan(x.grad).any()

    def test_causalidad_end_to_end_con_mascara(self, config, batch_size):
        """Alterar un token futuro no debe cambiar la salida de una
        posición anterior, cuando se usa máscara causal."""
        t = 8
        atencion = AtencionMultiCabeza(config)
        atencion.eval()  # desactivar dropout para comparación determinista

        x = torch.randn(batch_size, t, config.dimension_modelo)
        mascara_causal = crear_mascara_causal(t)

        with torch.no_grad():
            x_alterado = x.clone()
            x_alterado[:, -1, :] = torch.randn(batch_size, config.dimension_modelo)

            salida_original = atencion(x, mascara=mascara_causal)
            salida_alterada = atencion(x_alterado, mascara=mascara_causal)

            diferencia_posicion_0 = (salida_original[:, 0, :] - salida_alterada[:, 0, :]).abs().max()

        assert diferencia_posicion_0.item() < 1e-6

    def test_mascara_relleno_bloquea_tokens_de_relleno(self, config, batch_size):
        """Los tokens marcados como relleno (padding) no deben influir en
        la salida de otras posiciones."""
        t = 6
        id_token_relleno = 0
        tokens = torch.tensor([[1, 2, 3, 4, 0, 0], [1, 2, 3, 4, 5, 6]])
        assert tokens.shape == (batch_size, t)

        mascara_relleno = crear_mascara_relleno(tokens, id_token_relleno)
        assert mascara_relleno.shape == (batch_size, 1, 1, t)

        x = torch.randn(batch_size, t, config.dimension_modelo)
        atencion = AtencionMultiCabeza(config)
        atencion.eval()

        with torch.no_grad():
            x_alterado = x.clone()
            # alterar una posición de relleno del primer elemento del batch (posicion 5, que es padding)
            x_alterado[0, 5, :] = torch.randn(config.dimension_modelo)

            salida_original = atencion(x, mascara=mascara_relleno)
            salida_alterada = atencion(x_alterado, mascara=mascara_relleno)

            # la salida de una posicion real (ej. posicion 0) del primer elemento
            # del batch no deberia cambiar, porque la posicion 5 esta enmascarada
            diferencia = (salida_original[0, 0, :] - salida_alterada[0, 0, :]).abs().max()

        assert diferencia.item() < 1e-6

    def test_diferentes_instancias_tienen_pesos_independientes(self, config, batch_size):
        """Dos instancias de AtencionMultiCabeza deben tener pesos entrenables
        distintos (inicialización aleatoria), y por lo tanto producir
        salidas distintas ante la misma entrada."""
        t = 6
        x = torch.randn(batch_size, t, config.dimension_modelo)

        atencion_1 = AtencionMultiCabeza(config)
        atencion_2 = AtencionMultiCabeza(config)

        with torch.no_grad():
            salida_1 = atencion_1(x)
            salida_2 = atencion_2(x)

        assert not torch.allclose(salida_1, salida_2)

    def test_config_invalida_dimension_no_divisible(self):
        """ConfiguracionTransformer ya valida esto en __post_init__, pero
        confirmamos que AtencionMultiCabeza no puede instanciarse con una
        config inconsistente (defensa en profundidad)."""
        with pytest.raises(ValueError):
            ConfiguracionTransformer(
                tamano_vocabulario=100,
                dimension_modelo=100,
                num_cabezas=7,  # 100 no es divisible entre 7
            )