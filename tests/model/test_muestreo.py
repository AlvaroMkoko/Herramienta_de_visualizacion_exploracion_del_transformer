"""
Pruebas de `motor_llm/muestreo.py`: `aplicar_temperatura`, `filtrar_top_k`,
`filtrar_top_p`, `muestrear` y `muestrear_codicioso`.

Cubren:
- Que la temperatura afile/aplane la distribución como se espera.
- Que top-k conserve EXACTAMENTE k candidatos y descarte el resto.
- Que top-p conserve el conjunto más pequeño cuya probabilidad
  acumulada supera p (nucleus sampling), y que nunca deje el conjunto
  vacío.
- Que `muestrear_codicioso` sea 100% determinista.
- Que `muestrear` respete estadísticamente las distribuciones (sobre
  muchas muestras), y que `top_k=1` sea equivalente al muestreo
  codicioso.
- Validaciones de rango en los parámetros (temperatura > 0, k > 0,
  0 < p <= 1).
"""

import pytest
import torch

from model.motor_llm.muestreo import (
    aplicar_temperatura,
    filtrar_top_k,
    filtrar_top_p,
    muestrear,
    muestrear_codicioso,
)


# ---------------------------------------------------------------------------
# aplicar_temperatura
# ---------------------------------------------------------------------------

class TestAplicarTemperatura:
    def test_temperatura_uno_no_cambia_los_logits(self):
        logits = torch.tensor([[1.0, 2.0, 3.0]])
        resultado = aplicar_temperatura(logits, 1.0)
        assert torch.equal(resultado, logits)

    def test_temperatura_baja_afila_la_distribucion(self):
        logits = torch.tensor([[1.0, 2.0, 3.0, 4.0]])
        probs_original = torch.softmax(logits, dim=-1)
        probs_baja = torch.softmax(aplicar_temperatura(logits, 0.5), dim=-1)

        assert probs_baja.max().item() > probs_original.max().item()

    def test_temperatura_alta_aplana_la_distribucion(self):
        logits = torch.tensor([[1.0, 2.0, 3.0, 4.0]])
        probs_original = torch.softmax(logits, dim=-1)
        probs_alta = torch.softmax(aplicar_temperatura(logits, 2.0), dim=-1)

        assert probs_alta.max().item() < probs_original.max().item()

    @pytest.mark.parametrize("temperatura_invalida", [0.0, -1.0, -0.5])
    def test_temperatura_no_positiva_lanza_error(self, temperatura_invalida):
        logits = torch.tensor([[1.0, 2.0, 3.0]])
        with pytest.raises(ValueError):
            aplicar_temperatura(logits, temperatura_invalida)

    def test_preserva_la_forma(self):
        logits = torch.randn(3, 7, 50)  # forma arbitraria, no solo (B, vocab)
        resultado = aplicar_temperatura(logits, 0.8)
        assert resultado.shape == logits.shape


# ---------------------------------------------------------------------------
# filtrar_top_k
# ---------------------------------------------------------------------------

class TestFiltrarTopK:
    def test_conserva_exactamente_k_valores_finitos(self):
        logits = torch.tensor([[5.0, 1.0, 4.0, 2.0, 3.0]])
        filtrados = filtrar_top_k(logits, k=2)

        assert torch.isfinite(filtrados).sum().item() == 2

    def test_conserva_los_valores_correctos(self):
        logits = torch.tensor([[5.0, 1.0, 4.0, 2.0, 3.0]])
        filtrados = filtrar_top_k(logits, k=2)

        assert filtrados[0, 0].item() == 5.0
        assert filtrados[0, 2].item() == 4.0
        assert filtrados[0, 1].item() == float("-inf")
        assert filtrados[0, 3].item() == float("-inf")
        assert filtrados[0, 4].item() == float("-inf")

    def test_k_mayor_o_igual_al_vocabulario_no_filtra(self):
        logits = torch.tensor([[5.0, 1.0, 4.0, 2.0, 3.0]])
        filtrados = filtrar_top_k(logits, k=10)

        assert torch.equal(filtrados, logits)

    def test_k_igual_al_tamano_del_vocabulario_no_filtra(self):
        logits = torch.tensor([[5.0, 1.0, 4.0, 2.0, 3.0]])
        filtrados = filtrar_top_k(logits, k=5)

        assert torch.equal(filtrados, logits)

    @pytest.mark.parametrize("k_invalido", [0, -1, -5])
    def test_k_no_positivo_lanza_error(self, k_invalido):
        logits = torch.tensor([[1.0, 2.0, 3.0]])
        with pytest.raises(ValueError):
            filtrar_top_k(logits, k_invalido)

    def test_funciona_por_lotes_independientemente(self):
        logits = torch.tensor([
            [5.0, 1.0, 4.0, 2.0, 3.0],
            [1.0, 5.0, 2.0, 4.0, 3.0],
        ])
        filtrados = filtrar_top_k(logits, k=1)

        assert torch.isfinite(filtrados[0]).sum().item() == 1
        assert torch.isfinite(filtrados[1]).sum().item() == 1
        assert filtrados[0, 0].item() == 5.0
        assert filtrados[1, 1].item() == 5.0


# ---------------------------------------------------------------------------
# filtrar_top_p
# ---------------------------------------------------------------------------

class TestFiltrarTopP:
    def test_p_uno_no_filtra_nada(self):
        logits = torch.randn(1, 20)
        filtrados = filtrar_top_p(logits, p=1.0)

        assert torch.equal(filtrados, logits)

    def test_distribucion_muy_concentrada_conserva_pocos_tokens(self):
        logits = torch.tensor([[10.0, 1.0, 1.0, 1.0, 1.0]])
        filtrados = filtrar_top_p(logits, p=0.9)

        assert torch.isfinite(filtrados).sum().item() == 1

    def test_distribucion_uniforme_conserva_mas_tokens(self):
        logits_uniforme = torch.tensor([[1.0, 1.0, 1.0, 1.0, 1.0]])
        filtrados = filtrar_top_p(logits_uniforme, p=0.5)

        assert torch.isfinite(filtrados).sum().item() >= 3

    def test_nunca_deja_el_conjunto_vacio(self):
        logits = torch.tensor([[1.0, 1.0, 1.0, 1.0, 1.0]])
        filtrados = filtrar_top_p(logits, p=0.01)

        assert torch.isfinite(filtrados).sum().item() >= 1

    def test_conserva_el_token_de_mayor_probabilidad(self):
        logits = torch.tensor([[1.0, 9.0, 2.0, 3.0]])
        filtrados = filtrar_top_p(logits, p=0.3)

        assert torch.isfinite(filtrados[0, 1])
        assert filtrados[0, 1].item() == 9.0

    @pytest.mark.parametrize("p_invalido", [0.0, -0.1, 1.1, 2.0])
    def test_p_fuera_de_rango_lanza_error(self, p_invalido):
        logits = torch.tensor([[1.0, 2.0, 3.0]])
        with pytest.raises(ValueError):
            filtrar_top_p(logits, p_invalido)

    def test_preserva_el_orden_original_del_vocabulario(self):
        logits = torch.tensor([[1.0, 9.0, 2.0, 8.0, 0.5]])
        filtrados = filtrar_top_p(logits, p=0.99)

        indices_finitos = torch.isfinite(filtrados[0]).nonzero(as_tuple=True)[0].tolist()
        assert indices_finitos == sorted(indices_finitos)


# ---------------------------------------------------------------------------
# muestrear_codicioso
# ---------------------------------------------------------------------------

class TestMuestrearCodicioso:
    def test_elige_siempre_el_token_mas_probable(self):
        logits = torch.tensor([[1.0, 5.0, 2.0, 0.5]])

        for _ in range(10):
            token = muestrear_codicioso(logits)
            assert token.item() == 1

    def test_forma_de_salida(self):
        logits = torch.randn(4, 30)
        token = muestrear_codicioso(logits)

        assert token.shape == (4, 1)

    def test_es_determinista_entre_llamadas(self):
        logits = torch.randn(2, 15)
        token_1 = muestrear_codicioso(logits)
        token_2 = muestrear_codicioso(logits)

        assert torch.equal(token_1, token_2)


# ---------------------------------------------------------------------------
# muestrear (pipeline completo)
# ---------------------------------------------------------------------------

class TestMuestrear:
    def test_forma_de_salida(self):
        logits = torch.randn(3, 50)
        token = muestrear(logits, temperatura=1.0, top_k=10, top_p=0.9)

        assert token.shape == (3, 1)

    def test_ids_generados_estan_en_rango_valido(self):
        vocab_size = 40
        logits = torch.randn(5, vocab_size)

        for _ in range(20):
            token = muestrear(logits, temperatura=0.8, top_k=15, top_p=0.9)
            assert (token >= 0).all()
            assert (token < vocab_size).all()

    def test_top_k_uno_equivale_a_muestreo_codicioso(self):
        logits = torch.tensor([[1.0, 5.0, 2.0, 0.5]])

        for _ in range(10):
            token = muestrear(logits, temperatura=1.0, top_k=1)
            assert token.item() == 1

    def test_respeta_distribucion_uniforme_estadisticamente(self):
        torch.manual_seed(0)
        logits = torch.tensor([[1.0, 1.0, 1.0, 1.0]]).repeat(2000, 1)

        tokens = muestrear(logits, temperatura=1.0)
        conteos = torch.bincount(tokens.squeeze(), minlength=4).float()
        proporciones = conteos / conteos.sum()

        assert torch.allclose(proporciones, torch.full((4,), 0.25), atol=0.05)

    def test_temperatura_baja_concentra_el_muestreo(self):
        torch.manual_seed(0)
        logits = torch.tensor([[10.0, 1.0, 1.0]]).repeat(500, 1)

        tokens = muestrear(logits, temperatura=0.1)
        proporcion_dominante = (tokens.squeeze() == 0).float().mean().item()

        assert proporcion_dominante > 0.95

    def test_sin_filtros_opcionales_funciona_solo_con_temperatura(self):
        logits = torch.randn(2, 20)
        token = muestrear(logits, temperatura=1.0)

        assert token.shape == (2, 1)

    def test_combinacion_top_k_y_top_p_no_falla(self):
        logits = torch.randn(5, 100)

        for _ in range(20):
            token = muestrear(logits, temperatura=0.8, top_k=20, top_p=0.9)
            assert token.shape == (5, 1)