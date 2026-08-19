"""
Controlador de Teoría Contextual (CU17).

Este módulo NO contiene texto de teoría. Su única responsabilidad es
cargar, indexar y consultar `data/teoria/transformer.json`, de modo que
ampliar o corregir el contenido no requiera tocar código Python.

Diseño:
- La carga es perezosa (al primer acceso) y se cachea en memoria.
- Ninguna consulta lanza excepción: si falta el archivo, está corrupto o
  se pide un id inexistente, se devuelve una estructura vacía o de
  respaldo y se expone el motivo en `errorCarga`. La Vista llama a estos
  métodos desde clicks del diagrama, y una excepción ahí rompería la UI.
- `recargar()` permite editar el JSON y ver el cambio sin reiniciar.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from PySide6.QtCore import Property, QObject, Signal, Slot

RUTA_TEORIA_POR_DEFECTO = Path("data/teoria/transformer.json")


class TheoryController(QObject):
    """Acceso de solo lectura al contenido teórico.

    No depende de que exista un modelo creado: la teoría es la misma sin
    importar la configuración, así que está disponible desde el arranque.
    """

    teoriaRecargada = Signal()
    errorCargaCambio = Signal()

    def __init__(self, ruta: str | Path | None = None, parent: QObject | None = None):
        super().__init__(parent)
        self._ruta = Path(ruta) if ruta is not None else RUTA_TEORIA_POR_DEFECTO
        self._datos: dict[str, Any] | None = None
        self._indice: dict[str, dict[str, Any]] = {}
        self._seccion_de_concepto: dict[str, str] = {}
        self._error_carga = ""

    # ------------------------------------------------------------------
    # Carga
    # ------------------------------------------------------------------

    def _asegurar_cargado(self) -> None:
        """Carga perezosa: solo lee el archivo la primera vez que se
        consulta algo, no al construir el controlador."""
        if self._datos is not None:
            return
        self._cargar()

    def _cargar(self) -> None:
        self._datos = {"secciones": []}
        self._indice = {}
        self._seccion_de_concepto = {}
        error_previo = self._error_carga
        self._error_carga = ""

        try:
            with self._ruta.open(encoding="utf8") as archivo:
                datos = json.load(archivo)
        except FileNotFoundError:
            self._error_carga = f"No se encontró el archivo de teoría: {self._ruta}"
        except json.JSONDecodeError as error:
            self._error_carga = f"El archivo de teoría tiene JSON inválido: {error}"
        except OSError as error:
            self._error_carga = f"No se pudo leer el archivo de teoría: {error}"
        else:
            if not isinstance(datos, dict) or not isinstance(datos.get("secciones"), list):
                self._error_carga = "El archivo de teoría debe tener una lista 'secciones'."
            else:
                self._datos = datos
                self._construir_indice()

        if self._error_carga != error_previo:
            self.errorCargaCambio.emit()

    def _construir_indice(self) -> None:
        """Aplana los conceptos en un índice por id, para que las
        consultas sean directas en vez de recorrer todas las secciones."""
        for seccion in self._datos.get("secciones", []):
            if not isinstance(seccion, dict):
                continue
            id_seccion = seccion.get("id", "")
            for concepto in seccion.get("conceptos", []) or []:
                if not isinstance(concepto, dict):
                    continue
                id_concepto = concepto.get("id")
                if not id_concepto:
                    continue
                self._indice[id_concepto] = concepto
                self._seccion_de_concepto[id_concepto] = id_seccion

    @Property(str, notify=errorCargaCambio)
    def errorCarga(self) -> str:
        """Vacío si la carga fue correcta. La Vista puede mostrarlo para
        distinguir 'no hay teoría de esto' de 'el archivo no se pudo leer'."""
        self._asegurar_cargado()
        return self._error_carga

    @Slot(result=bool)
    def recargar(self) -> bool:
        """Vuelve a leer el archivo desde disco. Permite editar el JSON y
        ver el resultado sin reiniciar la aplicación."""
        self._datos = None
        self._asegurar_cargado()
        self.teoriaRecargada.emit()
        return not self._error_carga

    # ------------------------------------------------------------------
    # Consultas
    # ------------------------------------------------------------------

    @Slot(result="QVariantList")
    def obtenerSecciones(self) -> list:
        """Metadatos de las secciones, sin el contenido de los conceptos —
        pensado para armar un índice o menú sin cargar todo el texto.

        Devuelve `{"id", "title", "order", "cantidad_conceptos"}` por sección.
        """
        self._asegurar_cargado()
        secciones = []
        for seccion in self._datos.get("secciones", []):
            secciones.append({
                "id": seccion.get("id", ""),
                "title": seccion.get("title", ""),
                "order": seccion.get("order", 0),
                "cantidad_conceptos": len(seccion.get("conceptos", []) or []),
            })
        return sorted(secciones, key=lambda s: s["order"])

    @Slot(str, result="QVariantList")
    def obtenerConceptosDeSeccion(self, id_seccion: str) -> list:
        """Todos los conceptos de una sección, ordenados por `order`.
        Lista vacía si la sección no existe."""
        self._asegurar_cargado()
        for seccion in self._datos.get("secciones", []):
            if seccion.get("id") == id_seccion:
                conceptos = list(seccion.get("conceptos", []) or [])
                return sorted(conceptos, key=lambda c: c.get("order", 0))
        return []

    @Slot(str, result="QVariantMap")
    def obtenerConcepto(self, id_concepto: str) -> dict:
        """Un concepto completo por su id.

        Si no existe, devuelve una estructura de respaldo con las claves
        mínimas en vez de fallar — así un id mal escrito en el diagrama
        no rompe la tarjeta de teoría, solo muestra que falta contenido.
        """
        self._asegurar_cargado()
        concepto = self._indice.get(id_concepto)
        if concepto is None:
            return {
                "id": id_concepto,
                "title": "Sin información todavía",
                "short_description": "",
                "explanation": f'Todavía no hay teoría escrita para "{id_concepto}".',
                "existe": False,
            }
        resultado = dict(concepto)
        resultado["existe"] = True
        resultado["seccion"] = self._seccion_de_concepto.get(id_concepto, "")
        return resultado

    @Slot(str, result="QVariantList")
    def obtenerRelacionados(self, id_concepto: str) -> list:
        """Conceptos relacionados, ya resueltos a `{"id", "title",
        "short_description"}` — así la Vista puede ofrecer navegación sin
        tener que consultar cada id por separado. Ignora silenciosamente
        las referencias que apunten a conceptos inexistentes."""
        self._asegurar_cargado()
        concepto = self._indice.get(id_concepto)
        if concepto is None:
            return []

        relacionados = []
        for id_relacionado in concepto.get("related_concepts", []) or []:
            vecino = self._indice.get(id_relacionado)
            if vecino is None:
                continue
            relacionados.append({
                "id": vecino.get("id", ""),
                "title": vecino.get("title", ""),
                "short_description": vecino.get("short_description", ""),
            })
        return relacionados

    @Slot(result="QVariantList")
    def obtenerIdsDisponibles(self) -> list:
        """Todos los ids con contenido real — útil para verificar qué
        componentes del diagrama todavía no tienen teoría asociada."""
        self._asegurar_cargado()
        return list(self._indice.keys())

    @Slot(str, result="QVariantList")
    def buscar(self, texto: str) -> list:
        """Búsqueda por subcadena en título, descripción breve y
        explicación, sin distinguir mayúsculas.

        Devuelve `{"id", "title", "short_description", "seccion"}` de cada
        coincidencia. Con texto vacío devuelve lista vacía, no todo el
        contenido.
        """
        self._asegurar_cargado()
        consulta = (texto or "").strip().lower()
        if not consulta:
            return []

        resultados = []
        for id_concepto, concepto in self._indice.items():
            campos = " ".join([
                str(concepto.get("title", "")),
                str(concepto.get("short_description", "")),
                str(concepto.get("explanation", "")),
            ]).lower()
            if consulta in campos:
                resultados.append({
                    "id": id_concepto,
                    "title": concepto.get("title", ""),
                    "short_description": concepto.get("short_description", ""),
                    "seccion": self._seccion_de_concepto.get(id_concepto, ""),
                })
        return resultados

    @Slot(result="QVariantList")
    def obtenerRecorridoCompleto(self) -> list:
        """Todos los conceptos en el orden pedagógico recomendado
        (sección, luego concepto). Pensado para un modo 'recorrido
        guiado' donde el usuario avanza linealmente por toda la teoría."""
        self._asegurar_cargado()
        recorrido = []
        for seccion in sorted(
            self._datos.get("secciones", []), key=lambda s: s.get("order", 0)
        ):
            for concepto in sorted(
                seccion.get("conceptos", []) or [], key=lambda c: c.get("order", 0)
            ):
                recorrido.append({
                    "id": concepto.get("id", ""),
                    "title": concepto.get("title", ""),
                    "seccion": seccion.get("id", ""),
                    "seccion_title": seccion.get("title", ""),
                })
        return recorrido