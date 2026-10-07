"""Lógica de una clase en vivo, sin saber nada de sockets ni de Qt.

El transporte (hoy ``viewmodel/aula/servidor_lan.py``) sólo hace tres cosas:
avisar que una conexión llegó o se fue, entregar el texto recibido y enviar los
:class:`Envio` que esta clase devuelve. Gracias a eso la misma sesión podría
ejecutarse en un servidor en la nube con asyncio sin cambiar una línea.
"""

from __future__ import annotations

from collections import deque
from dataclasses import dataclass
import time
from typing import Any, Callable

from . import protocolo as p
from .apodos import ApodoInvalido, clave_apodo, sugerir_apodo, validar_apodo
from .archivo_clase import ArchivoInvalido, firma_valida
from .codigo_clase import normalizar_codigo
from .repositorio_clase import ACTIVO, EXPULSADO, PENDIENTE, RepositorioClase, ahora_iso

TODOS = "*"

#: Intentos fallidos (código o apodo) tolerados por conexión antes de cerrarla.
MAX_FALLOS_CONEXION = 5
#: Ventana y tope de fallos por dirección IP, para que reconectar en bucle no
#: sirva para adivinar el código.
VENTANA_FALLOS_ORIGEN = 60.0
MAX_FALLOS_ORIGEN = 15


@dataclass(frozen=True)
class Envio:
    destino: str
    mensaje: dict[str, Any]
    cerrar: bool = False


def _rechazo(motivo: str, texto: str, **extra: Any) -> dict[str, Any]:
    return p.mensaje("rechazo", motivo=motivo, mensaje=texto, **extra)


class SesionClase:
    def __init__(
        self,
        repositorio: RepositorioClase,
        palabras_bloqueadas: frozenset[str] = frozenset(),
        reloj: Callable[[], float] = time.monotonic,
    ) -> None:
        self.repo = repositorio
        self._bloqueadas = palabras_bloqueadas
        self._reloj = reloj
        self._conexiones: dict[str, dict[str, Any]] = {}
        self._fallos_origen: dict[str, deque[float]] = {}

    # ------------------------------------------------------------------
    # Ciclo de vida de conexiones
    # ------------------------------------------------------------------

    def conectar(self, conexion_id: str, origen: str = "") -> None:
        self._conexiones[conexion_id] = {
            "origen": origen,
            "alumno_id": "",
            "fallos": 0,
            "presencia": {},
            "visto": self._reloj(),
        }

    def desconectar(self, conexion_id: str) -> None:
        datos = self._conexiones.pop(conexion_id, None)
        if datos and datos["alumno_id"]:
            self.repo.actualizar_alumno(datos["alumno_id"], ultima_actividad=ahora_iso())

    def conexion_de(self, alumno_id: str) -> str:
        for conexion_id, datos in self._conexiones.items():
            if datos["alumno_id"] == alumno_id:
                return conexion_id
        return ""

    def conectados(self) -> dict[str, dict[str, Any]]:
        """``alumno_id → presencia`` de quienes tienen conexión abierta."""
        return {
            d["alumno_id"]: dict(d["presencia"])
            for d in self._conexiones.values()
            if d["alumno_id"]
        }

    # ------------------------------------------------------------------
    # Entrada principal
    # ------------------------------------------------------------------

    def procesar(self, conexion_id: str, texto: str) -> list[Envio]:
        conexion = self._conexiones.get(conexion_id)
        if conexion is None:
            return []
        conexion["visto"] = self._reloj()
        try:
            mensaje = p.decodificar(texto, p.MENSAJES_ALUMNO)
        except p.ErrorProtocolo as exc:
            cerrar = exc.motivo == p.VERSION_INCOMPATIBLE
            return [Envio(conexion_id, _rechazo(exc.motivo, str(exc)), cerrar)]

        tipo = mensaje["tipo"]
        if tipo in ("consulta", "hola"):
            if self._bloqueado(conexion):
                return [
                    Envio(
                        conexion_id,
                        _rechazo(
                            p.DEMASIADOS_INTENTOS,
                            "Demasiados intentos fallidos. Espera un minuto y revisa el código.",
                        ),
                        cerrar=True,
                    )
                ]
            if self.repo.clase.get("finalizada"):
                return [
                    Envio(
                        conexion_id,
                        _rechazo(p.CLASE_FINALIZADA, "El docente ya finalizó esta clase."),
                        cerrar=True,
                    )
                ]
            if normalizar_codigo(mensaje.get("codigo", "")) != self.repo.codigo:
                return self._fallo(
                    conexion_id,
                    _rechazo(p.CODIGO_INVALIDO, "El código de clase no es correcto."),
                )
            if tipo == "consulta":
                return [Envio(conexion_id, p.mensaje("info_clase", clase=self.repo.clase_publica()))]
            return self._hola(conexion_id, mensaje)

        alumno_id = conexion["alumno_id"]
        ficha = self.repo.alumno(alumno_id) if alumno_id else {}
        if not ficha or ficha.get("estado") != ACTIVO:
            return [
                Envio(
                    conexion_id,
                    _rechazo(p.NO_UNIDO, "Todavía no formas parte de la clase."),
                )
            ]
        if tipo == "presencia":
            conexion["presencia"] = {
                "modulo_id": str(mensaje.get("modulo_id", ""))[:40],
                "etapa": str(mensaje.get("etapa", ""))[:40],
            }
            return []
        if tipo == "progreso":
            snapshot = mensaje.get("snapshot")
            if not isinstance(snapshot, dict):
                return [Envio(conexion_id, _rechazo(p.MENSAJE_INVALIDO, "Progreso inválido."))]
            self.repo.guardar_progreso(alumno_id, snapshot, str(mensaje.get("generado_en", "")))
            return [Envio(conexion_id, p.mensaje("ack", resultados=[], progreso=True))]
        if tipo == "resultado":
            guardado = self._guardar_resultado(ficha, mensaje.get("resultado"))
            ids = [guardado] if guardado else []
            return [Envio(conexion_id, p.mensaje("ack", resultados=ids, progreso=False))]
        return []

    # ------------------------------------------------------------------
    # Unión a la clase
    # ------------------------------------------------------------------

    def _bloqueado(self, conexion: dict[str, Any]) -> bool:
        if conexion["fallos"] >= MAX_FALLOS_CONEXION:
            return True
        registro = self._fallos_origen.get(conexion["origen"])
        if not registro:
            return False
        limite = self._reloj() - VENTANA_FALLOS_ORIGEN
        while registro and registro[0] < limite:
            registro.popleft()
        return len(registro) >= MAX_FALLOS_ORIGEN

    def _fallo(self, conexion_id: str, rechazo: dict[str, Any]) -> list[Envio]:
        conexion = self._conexiones[conexion_id]
        conexion["fallos"] += 1
        self._fallos_origen.setdefault(conexion["origen"], deque()).append(self._reloj())
        return [Envio(conexion_id, rechazo, cerrar=self._bloqueado(conexion))]

    def _hola(self, conexion_id: str, mensaje: dict[str, Any]) -> list[Envio]:
        alumno_id = str(mensaje.get("alumno_id", ""))
        token = str(mensaje.get("token", ""))
        if self.repo.token_valido(alumno_id, token):
            return self._reconectar(conexion_id, alumno_id)

        try:
            apodo = validar_apodo(mensaje.get("apodo", ""), self._bloqueadas)
        except ApodoInvalido as exc:
            return self._fallo(conexion_id, _rechazo(p.APODO_INVALIDO, str(exc)))
        ocupados = self.repo.apodos_en_uso()
        if clave_apodo(apodo) in {clave_apodo(o) for o in ocupados}:
            sugerencia = sugerir_apodo(apodo, ocupados)
            return [
                Envio(
                    conexion_id,
                    _rechazo(
                        p.APODO_EN_USO,
                        f"Alguien ya usa «{apodo}». Prueba con «{sugerencia}».",
                        sugerencia=sugerencia,
                    ),
                )
            ]
        matricula = " ".join(str(mensaje.get("matricula", "")).split())[:40]
        if self.repo.clase.get("pedir_matricula") and not matricula:
            return [
                Envio(
                    conexion_id,
                    _rechazo(p.MATRICULA_REQUERIDA, "El docente pide tu matrícula para unirte."),
                )
            ]
        estado = PENDIENTE if self.repo.clase.get("aprobar_ingresos") else ACTIVO
        ficha = self.repo.agregar_alumno(
            apodo, matricula, str(mensaje.get("device_id", ""))[:64], estado=estado
        )
        self._conexiones[conexion_id]["alumno_id"] = ficha["alumno_id"]
        return [Envio(conexion_id, self._mensaje_ingreso(ficha))]

    def _reconectar(self, conexion_id: str, alumno_id: str) -> list[Envio]:
        ficha = self.repo.alumno(alumno_id)
        if ficha.get("estado") == EXPULSADO:
            return [
                Envio(
                    conexion_id,
                    _rechazo(p.EXPULSADO, "El docente te retiró de esta clase."),
                    cerrar=True,
                )
            ]
        envios: list[Envio] = []
        anterior = self.conexion_de(alumno_id)
        if anterior and anterior != conexion_id:
            # Mismo alumno abriendo la app en otra ventana o equipo: gana la
            # conexión nueva, y la vieja se entera de por qué la cierran.
            self._conexiones[anterior]["alumno_id"] = ""
            envios.append(
                Envio(
                    anterior,
                    p.mensaje(
                        "sesion_reemplazada",
                        mensaje="Tu cuenta de la clase se abrió en otra ventana o equipo.",
                    ),
                    cerrar=True,
                )
            )
        self._conexiones[conexion_id]["alumno_id"] = alumno_id
        ficha = self.repo.actualizar_alumno(alumno_id, ultima_actividad=ahora_iso())
        envios.append(Envio(conexion_id, self._mensaje_ingreso(ficha)))
        return envios

    def _mensaje_ingreso(self, ficha: dict[str, Any]) -> dict[str, Any]:
        tipo = "en_espera" if ficha.get("estado") == PENDIENTE else "bienvenida"
        return p.mensaje(
            tipo,
            alumno_id=ficha["alumno_id"],
            token=self.repo.token_de(ficha["alumno_id"]),
            apodo=ficha["apodo"],
            matricula=ficha.get("matricula", ""),
            clase=self.repo.clase_publica(),
        )

    # ------------------------------------------------------------------
    # Datos del alumno
    # ------------------------------------------------------------------

    def _identidad(self, ficha: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": ficha["alumno_id"],
            "nombre": ficha["apodo"],
            "apodo": ficha["apodo"],
            "matricula": ficha.get("matricula", ""),
            "grupo": self.repo.clase.get("grupo", ""),
            "edad": "",
            "correo": "",
            "origen": "aula",
        }

    def _guardar_resultado(self, ficha: dict[str, Any], resultado: Any) -> str:
        if not isinstance(resultado, dict) or not resultado.get("result_id"):
            return ""
        if resultado.get("assessment_type") not in ("pre", "post"):
            return ""
        result_id = str(resultado["result_id"])
        if self.repo.resultados.has_result(result_id):
            return result_id  # ya estaba: se confirma igual para vaciar la cola
        copia = dict(resultado)
        copia["student"] = self._identidad(ficha)
        copia["student_id"] = ficha["alumno_id"]
        return result_id if self.repo.resultados.save_unique(copia) else ""

    # ------------------------------------------------------------------
    # Acciones del docente
    # ------------------------------------------------------------------

    def _a_alumno(self, alumno_id: str, mensaje: dict[str, Any], cerrar: bool = False) -> list[Envio]:
        conexion_id = self.conexion_de(alumno_id)
        return [Envio(conexion_id, mensaje, cerrar)] if conexion_id else []

    def renombrar(self, alumno_id: str, apodo: str) -> list[Envio]:
        """Lanza :class:`ApodoInvalido` si el apodo no se puede usar."""
        if not self.repo.alumno(alumno_id):
            return []
        limpio = validar_apodo(apodo, self._bloqueadas)
        ocupados = self.repo.apodos_en_uso(excepto=alumno_id)
        if clave_apodo(limpio) in {clave_apodo(o) for o in ocupados}:
            raise ApodoInvalido(f"Otro alumno ya usa «{limpio}».")
        self.repo.actualizar_alumno(alumno_id, apodo=limpio)
        return self._a_alumno(alumno_id, p.mensaje("renombrado", apodo=limpio))

    def expulsar(self, alumno_id: str) -> list[Envio]:
        if not self.repo.alumno(alumno_id):
            return []
        self.repo.actualizar_alumno(alumno_id, estado=EXPULSADO)
        envios = self._a_alumno(
            alumno_id,
            p.mensaje("expulsado", mensaje="El docente te retiró de esta clase."),
            cerrar=True,
        )
        conexion_id = self.conexion_de(alumno_id)
        if conexion_id:
            self._conexiones[conexion_id]["alumno_id"] = ""
        return envios

    def readmitir(self, alumno_id: str) -> list[Envio]:
        if self.repo.alumno(alumno_id).get("estado") == EXPULSADO:
            self.repo.actualizar_alumno(alumno_id, estado=ACTIVO)
        return []

    def aprobar(self, alumno_id: str) -> list[Envio]:
        ficha = self.repo.alumno(alumno_id)
        if ficha.get("estado") != PENDIENTE:
            return []
        ficha = self.repo.actualizar_alumno(alumno_id, estado=ACTIVO)
        return self._a_alumno(alumno_id, self._mensaje_ingreso(ficha))

    def rechazar(self, alumno_id: str) -> list[Envio]:
        if self.repo.alumno(alumno_id).get("estado") != PENDIENTE:
            return []
        envios = self._a_alumno(
            alumno_id,
            _rechazo(p.EXPULSADO, "El docente no aceptó tu solicitud para unirte."),
            cerrar=True,
        )
        conexion_id = self.conexion_de(alumno_id)
        if conexion_id:
            self._conexiones[conexion_id]["alumno_id"] = ""
        self.repo.eliminar_alumno(alumno_id)
        return envios

    def aviso(self, texto: str) -> list[Envio]:
        limpio = " ".join(str(texto).split())[:500]
        if not limpio:
            return []
        return [Envio(TODOS, p.mensaje("aviso", texto=limpio))]

    def configurar(self, **campos: Any) -> list[Envio]:
        self.repo.actualizar_clase(**campos)
        return [Envio(TODOS, p.mensaje("config_clase", clase=self.repo.clase_publica()))]

    def finalizar(self) -> list[Envio]:
        self.repo.actualizar_clase(finalizada=True)
        return [
            Envio(
                TODOS,
                p.mensaje(
                    "clase_finalizada",
                    mensaje="El docente finalizó la clase. Tu avance sigue guardado en este equipo.",
                ),
                cerrar=True,
            )
        ]

    def destinatarios(self) -> list[str]:
        """Conexiones que reciben los envíos a ``TODOS``: sólo alumnos activos."""
        return [
            conexion_id
            for conexion_id, datos in self._conexiones.items()
            if datos["alumno_id"]
            and self.repo.alumno(datos["alumno_id"]).get("estado") == ACTIVO
        ]

    # ------------------------------------------------------------------
    # Importación de archivos .tvclase
    # ------------------------------------------------------------------

    def importar_paquete(self, paquete: dict[str, Any]) -> dict[str, Any]:
        """Integra un archivo exportado por un alumno. Lanza
        :class:`ArchivoInvalido` con un mensaje apto para el docente."""
        clase = paquete.get("clase", {})
        mismo_id = clase.get("class_id") and clase.get("class_id") == self.repo.class_id
        mismo_codigo = normalizar_codigo(clase.get("codigo", "")) == self.repo.codigo
        if not (mismo_id or mismo_codigo):
            raise ArchivoInvalido("El archivo pertenece a otra clase.")

        datos_alumno = paquete.get("alumno", {})
        alumno_id = str(datos_alumno.get("alumno_id", ""))
        device_id = str(datos_alumno.get("device_id", ""))[:64]
        ficha = self.repo.alumno(alumno_id) if alumno_id else {}
        nuevo = False
        if ficha:
            if not firma_valida(paquete, self.repo.token_de(alumno_id)):
                raise ArchivoInvalido(
                    "La firma del archivo no coincide: pudo haberse modificado a mano."
                )
        else:
            # Alumno que nunca se conectó: se busca por equipo para que
            # importar dos veces el mismo archivo no cree dos alumnos.
            ficha = next(
                (
                    a
                    for a in self.repo.alumnos()
                    if device_id and a.get("device_id") == device_id and a.get("origen") == "archivo"
                ),
                {},
            )
            if not ficha:
                try:
                    apodo = validar_apodo(datos_alumno.get("apodo", ""), self._bloqueadas)
                except ApodoInvalido:
                    apodo = "Alumno"
                apodo = sugerir_apodo(apodo, self.repo.apodos_en_uso())
                ficha = self.repo.agregar_alumno(
                    apodo,
                    " ".join(str(datos_alumno.get("matricula", "")).split())[:40],
                    device_id,
                    origen="archivo",
                    verificado=False,
                )
                nuevo = True
        if ficha.get("estado") == EXPULSADO:
            raise ArchivoInvalido(f"«{ficha['apodo']}» fue retirado de la clase.")

        progreso = self.repo.guardar_progreso(
            ficha["alumno_id"], paquete["progreso"], str(paquete.get("generado_en", ""))
        )
        nuevos = sum(
            1
            for resultado in paquete["resultados"]
            if not self.repo.resultados.has_result(str(resultado.get("result_id", "")))
            and self._guardar_resultado(ficha, resultado)
        )
        self.repo.actualizar_alumno(ficha["alumno_id"], ultima_actividad=ahora_iso())
        return {
            "alumno_id": ficha["alumno_id"],
            "apodo": ficha["apodo"],
            "verificado": bool(ficha.get("verificado", True)),
            "nuevo": nuevo,
            "resultados_nuevos": nuevos,
            "progreso_actualizado": progreso,
        }
