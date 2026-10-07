"""Aula conectada: el docente comparte un código y los alumnos se unen.

Capa sin Qt. El transporte por red vive en ``viewmodel/aula``; aquí sólo hay
protocolo, reglas de la clase y persistencia.
"""

from .analisis import analisis_modulo, exportar_csv, resumen_alumno
from .apodos import ApodoInvalido, cargar_palabras_bloqueadas, validar_apodo
from .archivo_clase import ArchivoInvalido, crear_paquete, guardar_paquete, leer_paquete
from .codigo_clase import formatear_codigo, generar_codigo, huella_codigo, normalizar_codigo
from .estado_alumno import EstadoAlumnoAula
from .repositorio_clase import RepositorioClase
from .sesion_clase import TODOS, Envio, SesionClase

__all__ = [
    "ApodoInvalido",
    "ArchivoInvalido",
    "Envio",
    "EstadoAlumnoAula",
    "RepositorioClase",
    "SesionClase",
    "TODOS",
    "analisis_modulo",
    "cargar_palabras_bloqueadas",
    "crear_paquete",
    "exportar_csv",
    "formatear_codigo",
    "generar_codigo",
    "guardar_paquete",
    "huella_codigo",
    "leer_paquete",
    "normalizar_codigo",
    "resumen_alumno",
    "validar_apodo",
]
