"""Lado del alumno: unirse con código y apodo, y sincronizar en segundo plano.

El alumno nunca depende de la red para avanzar. Este controlador observa el
curso y las evaluaciones locales y, cuando hay conexión con el docente, le
envía lo que falte. Si la conexión se cae, reintenta con espera creciente;
mientras tanto todo sigue guardándose en local y se envía al volver.

Estados (``estado``):

``sin_clase``       no pertenece a ninguna clase
``buscando``        broadcast UDP en curso
``conectando``      abriendo el WebSocket
``eligiendo_apodo`` el docente respondió; falta escribir apodo
``uniendo``         se envió ``hola``
``en_espera``       el docente debe aprobar el ingreso
``conectado``       dentro de la clase y sincronizando
``reconectando``    pertenece a una clase pero el docente no está accesible
``error``           el último intento falló; ``mensaje`` explica por qué
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot

from core.rutas import dato, recurso
from model.aula import protocolo as p
from model.aula.apodos import ApodoInvalido, cargar_palabras_bloqueadas, validar_apodo
from model.aula.archivo_clase import crear_paquete, guardar_paquete
from model.aula.codigo_clase import formatear_codigo, normalizar_codigo
from model.aula.estado_alumno import EstadoAlumnoAula

from .cliente_lan import ClienteAulaLan
from .red import separar_direccion

ESPERAS_REINTENTO_MS = (3000, 6000, 12000, 20000, 30000)
INTERVALO_PRESENCIA_MS = 20000

TEXTOS_ESTADO = {
    "sin_clase": "Sin clase",
    "buscando": "Buscando al docente…",
    "conectando": "Conectando…",
    "eligiendo_apodo": "Elige tu apodo",
    "uniendo": "Uniéndote…",
    "en_espera": "Esperando aprobación del docente",
    "conectado": "Conectado",
    "reconectando": "Sin conexión con el docente",
    "error": "No se pudo conectar",
}


def _ahora() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _ruta_local(url_o_ruta: str) -> Path:
    texto = str(url_o_ruta or "")
    url = QUrl(texto)
    return Path(url.toLocalFile()) if url.isLocalFile() else Path(texto)


class ClassroomStudentController(QObject):
    estadoCambio = Signal()
    avisoRecibido = Signal(str)

    def __init__(
        self,
        course_controller,
        results_repository,
        evaluation_controllers=(),
        profile_controller=None,
        parent: QObject | None = None,
        ruta_estado: Path | None = None,
        cliente: ClienteAulaLan | None = None,
    ) -> None:
        super().__init__(parent)
        self._course = course_controller
        self._results = results_repository
        self._profile = profile_controller
        self._estado_local = EstadoAlumnoAula(
            ruta_estado if ruta_estado is not None else dato("aula", "mi_clase.json")
        )
        self._bloqueadas = cargar_palabras_bloqueadas(
            recurso("data", "aula", "palabras_bloqueadas.json")
        )
        self._cliente = cliente or ClienteAulaLan(parent=self)
        self._cliente.encontrado.connect(self._al_encontrar)
        self._cliente.noEncontrado.connect(self._al_no_encontrar)
        self._cliente.conectado.connect(self._al_conectar)
        self._cliente.desconectado.connect(self._al_desconectar)
        self._cliente.fallo.connect(self._al_fallar)
        self._cliente.mensajeRecibido.connect(self._al_recibir)

        self._estado = "sin_clase"
        self._mensaje = ""
        self._sugerencia = ""
        self._aviso = ""
        self._codigo = ""
        self._clase_consultada: dict[str, Any] = {}
        self._direccion = ""
        self._intento_reconexion = 0
        self._probar_busqueda_al_fallar = False
        self._pausado = False

        self._reintento = QTimer(self)
        self._reintento.setSingleShot(True)
        self._reintento.timeout.connect(self._reconectar)
        self._envio_progreso = QTimer(self)
        self._envio_progreso.setSingleShot(True)
        self._envio_progreso.setInterval(800)
        self._envio_progreso.timeout.connect(self._enviar_progreso)
        self._presencia = QTimer(self)
        self._presencia.setInterval(INTERVALO_PRESENCIA_MS)
        self._presencia.timeout.connect(self._enviar_presencia)

        self._course.progressChanged.connect(self._envio_progreso.start)
        self._course.moduleChanged.connect(self._enviar_presencia)
        for controlador in evaluation_controllers:
            controlador.evaluationCompleted.connect(self._enviar_resultados_pendientes)
        if self._profile is not None:
            self._profile.profileChanged.connect(self._al_cambiar_perfil)

        if self._estado_local.unido:
            # Pertenece a una clase pero aún no hay conexión: el indicador
            # debe decirlo, no "Sin clase".
            self._estado = "reconectando"
            self._aplicar_clase(self._estado_local.clase)

    # ------------------------------------------------------------------
    # Propiedades para QML
    # ------------------------------------------------------------------

    @Property(str, notify=estadoCambio)
    def estado(self) -> str:
        return self._estado

    @Property(str, notify=estadoCambio)
    def estadoTexto(self) -> str:
        return TEXTOS_ESTADO.get(self._estado, self._estado)

    @Property(bool, notify=estadoCambio)
    def enClase(self) -> bool:
        return self._estado_local.unido

    @Property(bool, notify=estadoCambio)
    def conectado(self) -> bool:
        return self._estado == "conectado"

    @Property(bool, notify=estadoCambio)
    def ocupado(self) -> bool:
        return self._estado in ("buscando", "conectando", "uniendo")

    @Property(str, notify=estadoCambio)
    def codigo(self) -> str:
        clase = self._estado_local.clase
        return formatear_codigo(clase.get("codigo", "") or self._codigo)

    @Property(str, notify=estadoCambio)
    def nombreClase(self) -> str:
        clase = self._estado_local.clase or self._clase_consultada
        return str(clase.get("nombre", ""))

    @Property(str, notify=estadoCambio)
    def apodo(self) -> str:
        return str(self._estado_local.clase.get("apodo", ""))

    @Property(bool, notify=estadoCambio)
    def pedirMatricula(self) -> bool:
        clase = self._estado_local.clase or self._clase_consultada
        return bool(clase.get("pedir_matricula"))

    @Property(str, notify=estadoCambio)
    def mensaje(self) -> str:
        return self._mensaje

    @Property(str, notify=estadoCambio)
    def sugerenciaApodo(self) -> str:
        return self._sugerencia

    @Property(str, notify=estadoCambio)
    def ultimoAviso(self) -> str:
        return self._aviso

    @Property(str, notify=estadoCambio)
    def direccion(self) -> str:
        return self._direccion

    @Property(int, notify=estadoCambio)
    def pendientes(self) -> int:
        return len(self._estado_local.pendientes(self._resultados_locales()))

    # ------------------------------------------------------------------
    # Acciones de la interfaz
    # ------------------------------------------------------------------

    def _cambiar(self, estado: str, mensaje: str | None = None) -> None:
        self._estado = estado
        if mensaje is not None:
            self._mensaje = mensaje
        self.estadoCambio.emit()

    @Slot(str, result=bool)
    def buscarClase(self, codigo: str) -> bool:
        normalizado = normalizar_codigo(codigo)
        if not normalizado:
            self._cambiar("error", "El código tiene 6 caracteres, por ejemplo K7P-4QX.")
            return False
        if self._estado_local.unido:
            self._cambiar(self._estado, "Ya perteneces a una clase. Sal de ella antes de unirte a otra.")
            return False
        self._codigo = normalizado
        self._clase_consultada = {}
        self._sugerencia = ""
        self._direccion = ""
        self._cambiar("buscando", "")
        self._cliente.buscar(normalizado)
        return True

    @Slot(str, str, result=bool)
    def buscarPorDireccion(self, direccion: str, codigo: str) -> bool:
        normalizado = normalizar_codigo(codigo)
        host, puerto = separar_direccion(direccion, p.PUERTO_WEBSOCKET)
        if not normalizado or not host:
            self._cambiar(
                "error",
                "Escribe el código y la dirección que muestra el docente, por ejemplo 192.168.1.20:47801.",
            )
            return False
        if self._estado_local.unido:
            return False
        self._codigo = normalizado
        self._clase_consultada = {}
        self._sugerencia = ""
        self._conectar(host, puerto)
        return True

    @Slot(str, str, result=bool)
    def unirse(self, apodo: str, matricula: str) -> bool:
        if self._estado != "eligiendo_apodo" or not self._cliente.esta_conectado:
            self._cambiar("error", "Primero busca la clase con su código.")
            return False
        try:
            limpio = validar_apodo(apodo, self._bloqueadas)
        except ApodoInvalido as exc:
            self._cambiar("eligiendo_apodo", str(exc))
            return False
        matricula = " ".join(str(matricula).split())
        if self.pedirMatricula and not matricula:
            self._cambiar("eligiendo_apodo", "El docente pide tu matrícula para unirte.")
            return False
        self._sugerencia = ""
        self._cliente.enviar(
            p.mensaje(
                "hola",
                codigo=self._codigo,
                apodo=limpio,
                matricula=matricula,
                device_id=self._estado_local.device_id,
                app_version=p.VERSION_APLICACION,
            )
        )
        self._cambiar("uniendo", "")
        return True

    @Slot()
    def cancelar(self) -> None:
        self._cliente.cancelar_busqueda()
        if self._estado_local.unido:
            return
        self._cliente.cerrar()
        self._codigo = ""
        self._clase_consultada = {}
        self._cambiar("sin_clase", "")

    @Slot()
    def reintentar(self) -> None:
        if self._estado_local.unido:
            self._pausado = False
            self._intento_reconexion = 0
            self._reconectar()

    @Slot()
    def salirDeClase(self) -> None:
        self._detener_red()
        self._estado_local.salir()
        self._course.set_class_modules(None)
        self._codigo = ""
        self._aviso = ""
        self._cambiar("sin_clase", "Saliste de la clase. Tu avance sigue guardado en este equipo.")

    @Slot()
    def descartarAviso(self) -> None:
        self._aviso = ""
        self.estadoCambio.emit()

    @Slot(str, str, str, result=str)
    def exportarAvance(self, destino: str, codigo: str = "", apodo: str = "") -> str:
        """Guarda un ``.tvclase`` y devuelve su ruta, o ``""`` si falló.

        Si el alumno nunca pudo unirse por red, se usan el código y el apodo
        escritos en el diálogo; el docente verá el archivo como sin verificar.
        """
        clase = self._estado_local.clase
        if not clase:
            normalizado = normalizar_codigo(codigo)
            try:
                limpio = validar_apodo(apodo, self._bloqueadas)
            except ApodoInvalido as exc:
                self._cambiar(self._estado, str(exc))
                return ""
            if not normalizado:
                self._cambiar(self._estado, "Escribe el código de la clase para exportar tu avance.")
                return ""
            clase = {"codigo": normalizado, "apodo": limpio}
        paquete = crear_paquete(
            {
                "alumno_id": clase.get("alumno_id", ""),
                "apodo": clase.get("apodo", ""),
                "matricula": clase.get("matricula", ""),
                "device_id": self._estado_local.device_id,
            },
            clase,
            self._course.progress_snapshot(),
            self._resultados_locales(),
            _ahora(),
            token=str(clase.get("token", "")),
        )
        ruta = _ruta_local(destino)
        if not ruta.name:
            self._cambiar(self._estado, "Elige dónde guardar el archivo.")
            return ""
        try:
            guardada = guardar_paquete(ruta, paquete)
        except OSError as exc:
            self._cambiar(self._estado, f"No se pudo guardar el archivo: {exc}")
            return ""
        self._cambiar(self._estado, f"Avance exportado a {guardada.name}. Entrégalo a tu docente.")
        return str(guardada)

    # ------------------------------------------------------------------
    # Ciclo de conexión
    # ------------------------------------------------------------------

    def _al_cambiar_perfil(self) -> None:
        if self._profile is not None and self._profile.isStudent:
            self.iniciar()

    @Slot()
    def iniciar(self) -> None:
        """Reconecta en segundo plano si el alumno ya pertenece a una clase."""
        if self._estado_local.unido and self._estado in ("sin_clase", "error", "reconectando") and not self._pausado:
            if not self._reintento.isActive():
                self._reconectar()

    def _detener_red(self) -> None:
        self._reintento.stop()
        self._presencia.stop()
        self._envio_progreso.stop()
        self._cliente.cancelar_busqueda()
        self._cliente.cerrar()

    def _conectar(self, host: str, puerto: int) -> None:
        self._direccion = f"{host}:{puerto}"
        self._cambiar("conectando", "")
        self._cliente.conectar(host, puerto)

    def _reconectar(self) -> None:
        if not self._estado_local.unido or self._pausado:
            return
        clase = self._estado_local.clase
        self._codigo = normalizar_codigo(clase.get("codigo", ""))
        host, puerto = separar_direccion(clase.get("ultima_direccion", ""), p.PUERTO_WEBSOCKET)
        self._cambiar("reconectando")
        if host:
            # Primero la última dirección conocida; si el docente cambió de
            # IP (DHCP), se cae a buscar por código.
            self._probar_busqueda_al_fallar = True
            self._direccion = f"{host}:{puerto}"
            self._cliente.conectar(host, puerto)
        else:
            self._probar_busqueda_al_fallar = False
            self._cliente.buscar(self._codigo)

    def _programar_reintento(self) -> None:
        if not self._estado_local.unido or self._pausado:
            return
        espera = ESPERAS_REINTENTO_MS[min(self._intento_reconexion, len(ESPERAS_REINTENTO_MS) - 1)]
        self._intento_reconexion += 1
        self._reintento.start(espera)

    def _al_encontrar(self, host: str, puerto: int, nombre: str) -> None:
        if nombre and not self._estado_local.unido:
            self._clase_consultada = {"nombre": nombre}
        if self._estado_local.unido:
            self._direccion = f"{host}:{puerto}"
            self._cliente.conectar(host, puerto)
            return
        self._conectar(host, puerto)

    def _al_no_encontrar(self) -> None:
        if self._estado_local.unido:
            self._cambiar("reconectando")
            self._programar_reintento()
            return
        self._cambiar(
            "error",
            "No se encontró la clase en esta red. Revisa el código, que estés en la misma "
            "red que el docente, o usa «Conectar por dirección».",
        )

    def _al_fallar(self, texto: str) -> None:
        if self._estado_local.unido:
            if self._probar_busqueda_al_fallar:
                self._probar_busqueda_al_fallar = False
                self._cliente.buscar(self._codigo)
                return
            self._cambiar("reconectando")
            self._programar_reintento()
            return
        self._cambiar("error", texto)

    def _al_conectar(self) -> None:
        self._probar_busqueda_al_fallar = False
        if self._estado_local.unido:
            clase = self._estado_local.clase
            self._cliente.enviar(
                p.mensaje(
                    "hola",
                    codigo=self._codigo,
                    apodo=clase.get("apodo", ""),
                    matricula=clase.get("matricula", ""),
                    device_id=self._estado_local.device_id,
                    alumno_id=clase.get("alumno_id", ""),
                    token=clase.get("token", ""),
                    app_version=p.VERSION_APLICACION,
                )
            )
            return
        self._cliente.enviar(p.mensaje("consulta", codigo=self._codigo))

    def _al_desconectar(self) -> None:
        self._presencia.stop()
        if self._estado_local.unido:
            if self._estado != "error":
                self._cambiar("reconectando")
            self._programar_reintento()
            return
        if self._estado in ("eligiendo_apodo", "uniendo", "conectando"):
            self._cambiar("error", "Se perdió la conexión con el docente. Intenta de nuevo.")

    # ------------------------------------------------------------------
    # Mensajes del docente
    # ------------------------------------------------------------------

    def _al_recibir(self, mensaje: dict[str, Any]) -> None:
        tipo = mensaje.get("tipo")
        if tipo == "info_clase":
            self._clase_consultada = dict(mensaje.get("clase", {}))
            self._cambiar("eligiendo_apodo", "")
        elif tipo in ("bienvenida", "en_espera"):
            self._estado_local.registrar_union(mensaje, self._direccion)
            self._aplicar_clase(mensaje.get("clase", {}))
            self._intento_reconexion = 0
            if tipo == "en_espera":
                self._cambiar("en_espera", "Tu docente debe aceptarte en la clase.")
                return
            self._cambiar("conectado", "")
            self._sincronizar()
            self._presencia.start()
        elif tipo == "rechazo":
            self._al_rechazo(mensaje)
        elif tipo == "ack":
            self._estado_local.confirmar([str(i) for i in mensaje.get("resultados", [])])
            self.estadoCambio.emit()
        elif tipo == "config_clase":
            clase = dict(mensaje.get("clase", {}))
            self._estado_local.actualizar_clase(**clase)
            self._aplicar_clase(clase)
            self.estadoCambio.emit()
        elif tipo == "renombrado":
            self._estado_local.actualizar_clase(apodo=str(mensaje.get("apodo", "")))
            self._cambiar(self._estado, f"El docente cambió tu apodo a «{mensaje.get('apodo', '')}».")
        elif tipo == "aviso":
            self._aviso = str(mensaje.get("texto", ""))
            self.estadoCambio.emit()
            self.avisoRecibido.emit(self._aviso)
        elif tipo in ("expulsado", "clase_finalizada"):
            self._abandonar(str(mensaje.get("mensaje", "")))
        elif tipo == "sesion_reemplazada":
            # Sin reconexión automática: dos ventanas abiertas se quitarían la
            # sesión una a otra en bucle.
            self._pausado = True
            self._detener_red()
            self._cambiar("error", str(mensaje.get("mensaje", "")))

    def _al_rechazo(self, mensaje: dict[str, Any]) -> None:
        motivo = mensaje.get("motivo")
        texto = str(mensaje.get("mensaje", ""))
        if motivo in (p.APODO_EN_USO, p.APODO_INVALIDO, p.MATRICULA_REQUERIDA):
            self._sugerencia = str(mensaje.get("sugerencia", ""))
            self._cambiar("eligiendo_apodo", texto)
        elif motivo in (p.EXPULSADO, p.CLASE_FINALIZADA) and self._estado_local.unido:
            self._abandonar(texto)
        elif motivo == p.NO_UNIDO:
            return
        else:
            self._detener_red()
            if self._estado_local.unido:
                self._pausado = True
            self._cambiar("error", texto)

    def _abandonar(self, texto: str) -> None:
        self._detener_red()
        self._estado_local.salir()
        self._course.set_class_modules(None)
        self._cambiar("sin_clase", texto)

    def _aplicar_clase(self, clase: dict[str, Any]) -> None:
        modulos = clase.get("modulos_habilitados")
        self._course.set_class_modules(list(modulos) if isinstance(modulos, list) else None)

    # ------------------------------------------------------------------
    # Sincronización
    # ------------------------------------------------------------------

    def _resultados_locales(self) -> list[dict[str, Any]]:
        return self._results.get_history(student_id="__self__")

    def _sincronizar(self) -> None:
        self._enviar_progreso()
        self._enviar_resultados_pendientes()
        self._enviar_presencia()

    def _enviar_progreso(self) -> None:
        if self._estado != "conectado":
            return
        self._cliente.enviar(
            p.mensaje("progreso", snapshot=self._course.progress_snapshot(), generado_en=_ahora())
        )

    def _enviar_resultados_pendientes(self, *_args) -> None:
        if self._estado != "conectado":
            self.estadoCambio.emit()  # actualiza el contador de pendientes
            return
        for resultado in self._estado_local.pendientes(self._resultados_locales()):
            self._cliente.enviar(p.mensaje("resultado", resultado=resultado))
        self.estadoCambio.emit()

    def _enviar_presencia(self) -> None:
        if self._estado != "conectado":
            return
        modulo = self._course.currentModule
        self._cliente.enviar(
            p.mensaje(
                "presencia",
                modulo_id=str(modulo.get("id", "")),
                etapa=str(modulo.get("current_stage", "")),
            )
        )
