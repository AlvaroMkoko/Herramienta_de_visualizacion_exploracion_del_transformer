"""Persistencia de una clase en el equipo del docente.

Estructura en disco (una carpeta por clase, fácil de respaldar o copiar)::

    aula/clases/<class_id>/
        clase.json            configuración, código y secreto
        alumnos.json          fichas: apodo, matrícula, estado, origen
        progreso/<id>.json    último snapshot de avance de cada alumno
        resultados.json       un ResultsRepository normal

Los tokens no se guardan: se derivan con HMAC del secreto de la clase y el
``alumno_id``. Así el docente puede verificar un token o la firma de un
archivo ``.tvclase`` sin almacenar credenciales de cada alumno.
"""

from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timezone
import hashlib
import hmac
from pathlib import Path
import secrets
from typing import Any
import uuid

from model.evaluacion.results_repository import ResultsRepository

from ._json import escribir_json, leer_json
from .codigo_clase import generar_codigo

ESQUEMA_CLASE = 1

ACTIVO = "activo"
PENDIENTE = "pendiente"
EXPULSADO = "expulsado"


def ahora_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class RepositorioClase:
    def __init__(self, carpeta: Path) -> None:
        self.carpeta = Path(carpeta)
        self._clase: dict[str, Any] = leer_json(self.carpeta / "clase.json", {})
        if not self._clase.get("class_id"):
            raise FileNotFoundError(f"No hay una clase válida en {self.carpeta}")
        alumnos = leer_json(self.carpeta / "alumnos.json", {})
        self._alumnos: dict[str, dict[str, Any]] = (
            alumnos.get("alumnos", {}) if isinstance(alumnos, dict) else {}
        )
        self.resultados = ResultsRepository(self.carpeta / "resultados.json")

    # ------------------------------------------------------------------
    # Creación y listado
    # ------------------------------------------------------------------

    @classmethod
    def crear(
        cls,
        raiz: Path,
        nombre: str,
        grupo: str = "",
        pedir_matricula: bool = False,
        aprobar_ingresos: bool = False,
        codigos_ocupados: set[str] | None = None,
    ) -> "RepositorioClase":
        ocupados = codigos_ocupados if codigos_ocupados is not None else {
            c["codigo"] for c in cls.listar(raiz)
        }
        codigo = generar_codigo()
        while codigo in ocupados:
            codigo = generar_codigo()
        class_id = uuid.uuid4().hex[:12]
        carpeta = Path(raiz) / class_id
        escribir_json(
            carpeta / "clase.json",
            {
                "schema_version": ESQUEMA_CLASE,
                "class_id": class_id,
                "codigo": codigo,
                "nombre": " ".join(str(nombre).split()) or "Clase sin nombre",
                "grupo": " ".join(str(grupo).split()),
                "creada_en": ahora_iso(),
                "secreto": secrets.token_hex(32),
                "pedir_matricula": bool(pedir_matricula),
                "aprobar_ingresos": bool(aprobar_ingresos),
                # None = todos los módulos habilitados.
                "modulos_habilitados": None,
                "finalizada": False,
            },
        )
        escribir_json(carpeta / "alumnos.json", {"alumnos": {}})
        return cls(carpeta)

    @staticmethod
    def listar(raiz: Path) -> list[dict[str, Any]]:
        raiz = Path(raiz)
        if not raiz.is_dir():
            return []
        clases = []
        for carpeta in raiz.iterdir():
            datos = leer_json(carpeta / "clase.json", {})
            if not isinstance(datos, dict) or not datos.get("class_id"):
                continue
            alumnos = leer_json(carpeta / "alumnos.json", {}).get("alumnos", {})
            clases.append(
                {
                    "class_id": datos["class_id"],
                    "codigo": datos.get("codigo", ""),
                    "nombre": datos.get("nombre", ""),
                    "grupo": datos.get("grupo", ""),
                    "creada_en": datos.get("creada_en", ""),
                    "finalizada": bool(datos.get("finalizada")),
                    "alumnos": len(alumnos) if isinstance(alumnos, dict) else 0,
                    "carpeta": str(carpeta),
                }
            )
        clases.sort(key=lambda c: c["creada_en"], reverse=True)
        return clases

    # ------------------------------------------------------------------
    # Configuración de la clase
    # ------------------------------------------------------------------

    @property
    def clase(self) -> dict[str, Any]:
        return deepcopy(self._clase)

    @property
    def class_id(self) -> str:
        return str(self._clase["class_id"])

    @property
    def codigo(self) -> str:
        return str(self._clase["codigo"])

    def clase_publica(self) -> dict[str, Any]:
        """Lo que se envía a los alumnos: nunca incluye el secreto."""
        return {
            "class_id": self.class_id,
            "codigo": self.codigo,
            "nombre": self._clase.get("nombre", ""),
            "grupo": self._clase.get("grupo", ""),
            "pedir_matricula": bool(self._clase.get("pedir_matricula")),
            "modulos_habilitados": deepcopy(self._clase.get("modulos_habilitados")),
            "finalizada": bool(self._clase.get("finalizada")),
        }

    def actualizar_clase(self, **campos: Any) -> None:
        permitidos = {
            "nombre",
            "grupo",
            "pedir_matricula",
            "aprobar_ingresos",
            "modulos_habilitados",
            "finalizada",
        }
        for clave, valor in campos.items():
            if clave in permitidos:
                self._clase[clave] = deepcopy(valor)
        escribir_json(self.carpeta / "clase.json", self._clase)

    # ------------------------------------------------------------------
    # Tokens
    # ------------------------------------------------------------------

    def token_de(self, alumno_id: str) -> str:
        clave = bytes.fromhex(self._clase["secreto"])
        return hmac.new(clave, alumno_id.encode("utf-8"), hashlib.sha256).hexdigest()[:40]

    def token_valido(self, alumno_id: str, token: str) -> bool:
        if not alumno_id or not token or alumno_id not in self._alumnos:
            return False
        return hmac.compare_digest(self.token_de(alumno_id), str(token))

    # ------------------------------------------------------------------
    # Alumnos
    # ------------------------------------------------------------------

    def alumnos(self) -> list[dict[str, Any]]:
        return [deepcopy(a) for a in self._alumnos.values()]

    def alumno(self, alumno_id: str) -> dict[str, Any]:
        return deepcopy(self._alumnos.get(alumno_id, {}))

    def apodos_en_uso(self, excepto: str = "") -> list[str]:
        return [
            a["apodo"]
            for a in self._alumnos.values()
            if a["alumno_id"] != excepto and a.get("estado") != EXPULSADO
        ]

    def agregar_alumno(
        self,
        apodo: str,
        matricula: str,
        device_id: str,
        estado: str = ACTIVO,
        origen: str = "red",
        verificado: bool = True,
    ) -> dict[str, Any]:
        alumno_id = "al-" + uuid.uuid4().hex[:10]
        ficha = {
            "alumno_id": alumno_id,
            "apodo": apodo,
            "matricula": matricula,
            "device_id": device_id,
            "estado": estado,
            "origen": origen,
            "verificado": bool(verificado),
            "unido_en": ahora_iso(),
            "ultima_actividad": ahora_iso(),
        }
        self._alumnos[alumno_id] = ficha
        self._guardar_alumnos()
        return deepcopy(ficha)

    def actualizar_alumno(self, alumno_id: str, **campos: Any) -> dict[str, Any]:
        ficha = self._alumnos.get(alumno_id)
        if ficha is None:
            return {}
        ficha.update(deepcopy(campos))
        self._guardar_alumnos()
        return deepcopy(ficha)

    def eliminar_alumno(self, alumno_id: str) -> None:
        if self._alumnos.pop(alumno_id, None) is not None:
            self._guardar_alumnos()

    def _guardar_alumnos(self) -> None:
        escribir_json(self.carpeta / "alumnos.json", {"alumnos": self._alumnos})

    # ------------------------------------------------------------------
    # Progreso y resultados
    # ------------------------------------------------------------------

    def _ruta_progreso(self, alumno_id: str) -> Path:
        return self.carpeta / "progreso" / f"{alumno_id}.json"

    def progreso(self, alumno_id: str) -> dict[str, Any]:
        datos = leer_json(self._ruta_progreso(alumno_id), {})
        return datos if isinstance(datos, dict) else {}

    def guardar_progreso(self, alumno_id: str, snapshot: dict[str, Any], generado_en: str) -> bool:
        """Reemplaza el snapshot sólo si es igual o más reciente.

        Un archivo ``.tvclase`` exportado ayer no debe pisar lo que llegó hoy
        por la red.
        """
        anterior = self.progreso(alumno_id)
        if anterior and str(anterior.get("generado_en", "")) > str(generado_en):
            return False
        escribir_json(
            self._ruta_progreso(alumno_id),
            {
                "snapshot": deepcopy(snapshot),
                "generado_en": str(generado_en),
                "recibido_en": ahora_iso(),
            },
        )
        return True

    def snapshot_de(self, alumno_id: str) -> dict[str, Any]:
        return deepcopy(self.progreso(alumno_id).get("snapshot", {}))

    def resultados_de(self, alumno_id: str) -> list[dict[str, Any]]:
        return self.resultados.get_history(student_id=alumno_id)
