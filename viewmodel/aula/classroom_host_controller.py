"""Lado del docente: crear la clase, verla en vivo y controlarla.

Mientras la clase está abierta, la app del docente es el servidor (opción A
en la red de la escuela, opción B si es su propio hotspot o router). Los datos
de cada clase quedan en ``aula/clases/<class_id>/`` y pueden reabrirse otro
día con el mismo código. Los archivos ``.tvclase`` (opción D) entran por la
misma :class:`SesionClase`, así que red y archivo nunca duplican resultados.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot

from core.rutas import dato, recurso
from model.aprendizaje import LearningModuleCatalog
from model.aula import analisis
from model.aula.apodos import ApodoInvalido, cargar_palabras_bloqueadas
from model.aula.archivo_clase import ArchivoInvalido, leer_paquete
from model.aula.codigo_clase import formatear_codigo
from model.aula.repositorio_clase import EXPULSADO, PENDIENTE, RepositorioClase
from model.aula.sesion_clase import SesionClase
from model.aula import protocolo as p

from .red import interfaces_locales
from .servidor_lan import ServidorAulaLan

ETIQUETAS_ETAPA = {
    "pretest": "Pre-test",
    "guided": "Recorrido guiado",
    "laboratory": "Laboratorio",
    "posttest": "Post-test",
    "results": "Resultados",
    "completed": "Módulo completado",
}


def _ruta_local(url_o_ruta: str) -> Path:
    texto = str(url_o_ruta or "")
    url = QUrl(texto)
    return Path(url.toLocalFile()) if url.isLocalFile() else Path(texto)


def _hora_legible(iso: str) -> str:
    try:
        momento = datetime.fromisoformat(str(iso)).astimezone()
    except ValueError:
        return ""
    return momento.strftime("%d/%m %H:%M")


class ClassroomHostController(QObject):
    claseCambio = Signal()
    alumnosCambio = Signal()
    clasesGuardadasCambio = Signal()
    mensajeCambio = Signal()

    def __init__(
        self,
        parent: QObject | None = None,
        raiz_clases: Path | None = None,
        catalog: LearningModuleCatalog | None = None,
        puerto_websocket: int = p.PUERTO_WEBSOCKET,
        puerto_descubrimiento: int = p.PUERTO_DESCUBRIMIENTO,
    ) -> None:
        super().__init__(parent)
        self._raiz = Path(raiz_clases) if raiz_clases is not None else dato("aula", "clases")
        self._catalog = catalog or LearningModuleCatalog()
        self._puertos = (puerto_websocket, puerto_descubrimiento)
        self._bloqueadas = cargar_palabras_bloqueadas(
            recurso("data", "aula", "palabras_bloqueadas.json")
        )
        self._repo: RepositorioClase | None = None
        self._sesion: SesionClase | None = None
        self._servidor: ServidorAulaLan | None = None
        self._mensaje = ""
        self._filas: list[dict[str, Any]] = []
        self._refresco = QTimer(self)
        self._refresco.setSingleShot(True)
        self._refresco.setInterval(250)
        self._refresco.timeout.connect(self._recalcular)

    # ------------------------------------------------------------------
    # Propiedades de la clase
    # ------------------------------------------------------------------

    @Property(bool, notify=claseCambio)
    def activa(self) -> bool:
        return self._servidor is not None and self._servidor.escuchando

    @Property(str, notify=claseCambio)
    def classId(self) -> str:
        return self._repo.class_id if self._repo else ""

    @Property(str, notify=claseCambio)
    def codigo(self) -> str:
        return formatear_codigo(self._repo.codigo) if self._repo else ""

    @Property(str, notify=claseCambio)
    def nombreClase(self) -> str:
        return str(self._repo.clase.get("nombre", "")) if self._repo else ""

    @Property(str, notify=claseCambio)
    def grupo(self) -> str:
        return str(self._repo.clase.get("grupo", "")) if self._repo else ""

    @Property(bool, notify=claseCambio)
    def pedirMatricula(self) -> bool:
        return bool(self._repo and self._repo.clase.get("pedir_matricula"))

    @Property(bool, notify=claseCambio)
    def aprobarIngresos(self) -> bool:
        return bool(self._repo and self._repo.clase.get("aprobar_ingresos"))

    @Property(bool, notify=claseCambio)
    def finalizada(self) -> bool:
        return bool(self._repo and self._repo.clase.get("finalizada"))

    @Property(int, notify=claseCambio)
    def puerto(self) -> int:
        return self._servidor.puerto if self._servidor else 0

    @Property(bool, notify=claseCambio)
    def descubrimientoActivo(self) -> bool:
        return bool(self._servidor and self._servidor.descubrimiento_activo)

    @Property("QVariantList", notify=claseCambio)
    def direcciones(self) -> list[dict[str, Any]]:
        if not self.activa:
            return []
        return [
            {**fila, "direccion": f"{fila['ip']}:{self.puerto}"}
            for fila in interfaces_locales()
        ]

    @Property("QVariantList", notify=claseCambio)
    def modulos(self) -> list[dict[str, Any]]:
        habilitados = self._repo.clase.get("modulos_habilitados") if self._repo else None
        return [
            {
                "id": modulo["id"],
                "order": modulo.get("order", 0),
                "title": modulo.get("title", modulo["id"]),
                "habilitado": habilitados is None or modulo["id"] in habilitados,
            }
            for modulo in self._catalog.modules
        ]

    @Property(str, notify=mensajeCambio)
    def mensaje(self) -> str:
        return self._mensaje

    @Property("QVariantList", notify=clasesGuardadasCambio)
    def clasesGuardadas(self) -> list[dict[str, Any]]:
        return [
            {**clase, "codigo": formatear_codigo(clase["codigo"]), "creada": _hora_legible(clase["creada_en"])}
            for clase in RepositorioClase.listar(self._raiz)
        ]

    @Property("QVariantList", constant=True)
    def interfacesRed(self) -> list[dict[str, Any]]:
        return interfaces_locales()

    # ------------------------------------------------------------------
    # Alumnos
    # ------------------------------------------------------------------

    @Property("QVariantList", notify=alumnosCambio)
    def alumnos(self) -> list[dict[str, Any]]:
        return self._filas

    @Property(int, notify=alumnosCambio)
    def totalAlumnos(self) -> int:
        return sum(fila["estado"] != EXPULSADO for fila in self._filas)

    @Property(int, notify=alumnosCambio)
    def conectados(self) -> int:
        return sum(bool(fila["conectado"]) for fila in self._filas)

    @Property(int, notify=alumnosCambio)
    def pendientesAprobacion(self) -> int:
        return sum(fila["estado"] == PENDIENTE for fila in self._filas)

    def _recalcular(self) -> None:
        if self._repo is None:
            self._filas = []
            self.alumnosCambio.emit()
            return
        presentes = self._sesion.conectados() if self._sesion else {}
        titulos = {m["id"]: m for m in self._catalog.modules}
        module_ids = list(self._catalog.module_ids)
        filas = []
        for ficha in self._repo.alumnos():
            alumno_id = ficha["alumno_id"]
            resumen = analisis.resumen_alumno(
                module_ids, self._repo.snapshot_de(alumno_id), self._repo.resultados_de(alumno_id)
            )
            presencia = presentes.get(alumno_id)
            modulo_id = (presencia or {}).get("modulo_id") or resumen["current_module_id"]
            modulo = titulos.get(modulo_id, {})
            etapa = (presencia or {}).get("etapa") or next(
                (m["current_stage"] for m in resumen["modules"] if m["module_id"] == modulo_id),
                "",
            )
            filas.append(
                {
                    "alumno_id": alumno_id,
                    "apodo": ficha.get("apodo", ""),
                    "matricula": ficha.get("matricula", ""),
                    "estado": ficha.get("estado", ""),
                    "origen": ficha.get("origen", "red"),
                    "verificado": bool(ficha.get("verificado", True)),
                    "conectado": presencia is not None,
                    "global_percent": resumen["global_percent"],
                    "completed_modules": resumen["completed_modules"],
                    "modulo_actual": (
                        f"M{modulo.get('order', '?')} · {modulo.get('title', '')}" if modulo else "—"
                    ),
                    "etapa": ETIQUETAS_ETAPA.get(etapa, etapa or "—"),
                    "modules": [
                        {
                            "module_id": m["module_id"],
                            "status": m["status"],
                            "progress_percent": m["progress_percent"],
                            "post_percentage": m["post_percentage"],
                        }
                        for m in resumen["modules"]
                    ],
                    "ultima_actividad": _hora_legible(ficha.get("ultima_actividad", "")),
                }
            )
        orden_estado = {PENDIENTE: 0, "activo": 1, EXPULSADO: 2}
        filas.sort(
            key=lambda f: (orden_estado.get(f["estado"], 3), not f["conectado"], f["apodo"].casefold())
        )
        self._filas = filas
        self.alumnosCambio.emit()

    def _programar_refresco(self) -> None:
        if not self._refresco.isActive():
            self._refresco.start()

    # ------------------------------------------------------------------
    # Crear, abrir y cerrar
    # ------------------------------------------------------------------

    def _avisar(self, texto: str) -> None:
        self._mensaje = texto
        self.mensajeCambio.emit()

    @Slot(str, str, bool, bool, result=bool)
    def crearClase(self, nombre: str, grupo: str, pedir_matricula: bool, aprobar_ingresos: bool) -> bool:
        if not " ".join(str(nombre).split()):
            self._avisar("Escribe un nombre para la clase.")
            return False
        repo = RepositorioClase.crear(
            self._raiz, nombre, grupo, pedir_matricula=pedir_matricula, aprobar_ingresos=aprobar_ingresos
        )
        self.clasesGuardadasCambio.emit()
        return self._abrir(repo)

    @Slot(str, result=bool)
    def abrirClase(self, class_id: str) -> bool:
        try:
            repo = RepositorioClase(self._raiz / str(class_id))
        except FileNotFoundError:
            self._avisar("No se encontró esa clase en este equipo.")
            return False
        if repo.clase.get("finalizada"):
            # Reabrirla es una decisión explícita del docente.
            repo.actualizar_clase(finalizada=False)
        return self._abrir(repo)

    def _abrir(self, repo: RepositorioClase) -> bool:
        self.detenerClase()
        sesion = SesionClase(repo, self._bloqueadas)
        servidor = ServidorAulaLan(sesion, *self._puertos, parent=self)
        error = servidor.iniciar()
        if error:
            servidor.deleteLater()
            self._avisar(error)
            return False
        servidor.actividad.connect(self._programar_refresco)
        self._repo, self._sesion, self._servidor = repo, sesion, servidor
        self._avisar(
            ""
            if servidor.descubrimiento_activo
            else "La búsqueda automática no está disponible en este equipo: comparte la dirección "
            "para que los alumnos usen «Conectar por dirección»."
        )
        self.claseCambio.emit()
        self._recalcular()
        return True

    @Slot()
    def detenerClase(self) -> None:
        """Cierra el servidor sin finalizar la clase: los alumnos esperan y
        se reconectan solos cuando el docente vuelva a abrirla."""
        if self._servidor is not None:
            self._servidor.detener()
            self._servidor.deleteLater()
        self._servidor = None
        self._sesion = None
        self._repo = None
        self._filas = []
        self.claseCambio.emit()
        self.alumnosCambio.emit()
        self.clasesGuardadasCambio.emit()

    @Slot()
    def finalizarClase(self) -> None:
        if self._sesion is None:
            return
        self._servidor.enviar(self._sesion.finalizar())
        self.detenerClase()

    @Slot()
    def actualizarClases(self) -> None:
        self.clasesGuardadasCambio.emit()

    # ------------------------------------------------------------------
    # Acciones sobre alumnos y clase
    # ------------------------------------------------------------------

    def _ejecutar(self, envios) -> None:
        if self._servidor is not None:
            self._servidor.enviar(envios)
        self._programar_refresco()

    @Slot(str, str, result=bool)
    def renombrarAlumno(self, alumno_id: str, apodo: str) -> bool:
        if self._sesion is None:
            return False
        try:
            self._ejecutar(self._sesion.renombrar(alumno_id, apodo))
        except ApodoInvalido as exc:
            self._avisar(str(exc))
            return False
        self._avisar("")
        return True

    @Slot(str)
    def expulsarAlumno(self, alumno_id: str) -> None:
        if self._sesion is not None:
            self._ejecutar(self._sesion.expulsar(alumno_id))

    @Slot(str)
    def readmitirAlumno(self, alumno_id: str) -> None:
        if self._sesion is not None:
            self._ejecutar(self._sesion.readmitir(alumno_id))

    @Slot(str)
    def aprobarAlumno(self, alumno_id: str) -> None:
        if self._sesion is not None:
            self._ejecutar(self._sesion.aprobar(alumno_id))

    @Slot(str)
    def rechazarAlumno(self, alumno_id: str) -> None:
        if self._sesion is not None:
            self._ejecutar(self._sesion.rechazar(alumno_id))

    @Slot(str, result=bool)
    def enviarAviso(self, texto: str) -> bool:
        if self._sesion is None:
            return False
        envios = self._sesion.aviso(texto)
        self._ejecutar(envios)
        return bool(envios)

    def _configurar(self, **campos: Any) -> None:
        if self._sesion is None:
            return
        self._ejecutar(self._sesion.configurar(**campos))
        self.claseCambio.emit()

    @Slot(str, bool)
    def habilitarModulo(self, module_id: str, habilitado: bool) -> None:
        if self._repo is None or module_id not in self._catalog.module_ids:
            return
        actuales = self._repo.clase.get("modulos_habilitados")
        conjunto = set(self._catalog.module_ids if actuales is None else actuales)
        if habilitado:
            conjunto.add(module_id)
        else:
            conjunto.discard(module_id)
        ordenados = [m for m in self._catalog.module_ids if m in conjunto]
        self._configurar(
            modulos_habilitados=None if len(ordenados) == len(self._catalog.module_ids) else ordenados
        )

    @Slot(bool)
    def setAprobarIngresos(self, valor: bool) -> None:
        self._configurar(aprobar_ingresos=bool(valor))

    @Slot(bool)
    def setPedirMatricula(self, valor: bool) -> None:
        self._configurar(pedir_matricula=bool(valor))

    # ------------------------------------------------------------------
    # Análisis, exportación e importación
    # ------------------------------------------------------------------

    def _alumnos_con_resultados(self) -> list[tuple[dict[str, Any], list[dict[str, Any]]]]:
        if self._repo is None:
            return []
        return [
            (ficha, self._repo.resultados_de(ficha["alumno_id"]))
            for ficha in self._repo.alumnos()
            if ficha.get("estado") != PENDIENTE
        ]

    @Slot(str, result="QVariantMap")
    def analisisModulo(self, module_id: str) -> dict[str, Any]:
        if self._repo is None or module_id not in self._catalog.module_ids:
            return {}
        return analisis.analisis_modulo(self._catalog.get(module_id), self._alumnos_con_resultados())

    @Slot(str, result=str)
    def exportarCsv(self, destino: str) -> str:
        if self._repo is None:
            return ""
        ruta = _ruta_local(destino)
        if ruta.suffix.lower() != ".csv":
            ruta = ruta.with_name(ruta.name + ".csv")
        try:
            ruta.parent.mkdir(parents=True, exist_ok=True)
            # utf-8-sig: Excel en español abre bien los acentos.
            ruta.write_text(
                analisis.exportar_csv(self._alumnos_con_resultados()), encoding="utf-8-sig"
            )
        except OSError as exc:
            self._avisar(f"No se pudo guardar el CSV: {exc}")
            return ""
        self._avisar(f"Resultados exportados a {ruta.name}.")
        return str(ruta)

    @Slot("QVariantList", result=str)
    def importarArchivos(self, rutas: list[Any]) -> str:
        if self._sesion is None:
            self._avisar("Abre la clase antes de importar archivos.")
            return self._mensaje
        lineas = []
        for entrada in rutas:
            ruta = _ruta_local(str(entrada))
            try:
                resumen = self._sesion.importar_paquete(leer_paquete(ruta))
            except ArchivoInvalido as exc:
                lineas.append(f"{ruta.name}: {exc}")
                continue
            verificacion = "" if resumen["verificado"] else " (sin verificar)"
            lineas.append(
                f"{ruta.name}: {resumen['apodo']}{verificacion}, "
                f"{resumen['resultados_nuevos']} evaluación(es) nueva(s)"
            )
        self._programar_refresco()
        self._avisar("\n".join(lineas))
        return self._mensaje
