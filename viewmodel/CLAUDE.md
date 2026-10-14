# viewmodel/ — al trabajar aquí

Se carga solo al trabajar en `viewmodel/`. Las reglas generales están en el `CLAUDE.md` raíz.

Las convenciones de PySide6 viven en `docs/architecture.md` → *ViewModel*: las cinco
*Convenciones obligatorias del ViewModel* (romper cualquiera no produce error, solo una
propiedad `undefined` o un botón muerto), *Separación de señales* y *Concurrencia: tres
mecanismos distintos, no uno*. Léelas antes de agregar un `@Slot`, una `@Property`, una señal o
un hilo.
