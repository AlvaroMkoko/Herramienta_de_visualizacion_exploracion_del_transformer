from entrenar import _duracion_breve, _linea_progreso_entrenamiento


def test_linea_progreso_muestra_sesion_lote_porcentaje_y_eta() -> None:
    linea = _linea_progreso_entrenamiento(
        completados=5,
        total=20,
        epoca_sesion=1,
        epocas_sesion=4,
        lote=5,
        lotes_epoca=5,
        perdida=1.23456,
        transcurrido=10.0,
    )

    assert "25.0%" in linea
    assert "época 1/4" in linea
    assert "lote 5/5" in linea
    assert "pérdida 1.2346" in linea
    assert "ETA 30s" in linea


def test_duracion_breve_no_muestra_valores_negativos() -> None:
    assert _duracion_breve(-10) == "0s"
    assert _duracion_breve(65) == "1m 05s"

