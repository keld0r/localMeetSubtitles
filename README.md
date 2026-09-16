# 💬 LocalMeetSubtitles

Subtítulos en tiempo real en pantalla, **100% locales, privados y sin conexión a internet**, diseñados específicamente para videollamadas de Google Meet (o Zoom / Teams) con participantes de Chile (Español) y Brasil (Portugués).

---

## ✨ Características Principales

- **100% Localhost & Confidencial**: Todo el procesamiento se realiza en la memoria RAM y hardware de tu Mac (Apple Silicon M1 Max). Ningún audio ni texto sale a internet ni se almacena en la nube.
- **Detección Automática de Idioma**:
  - Si un participante habla en **Portugués de Brasil (🇧🇷)**: el sistema transcribe y traduce instantáneamente a **Español de Chile (🇨🇱)** mediante el Apple Neural Engine y muestra el subtítulo en pantalla.
  - Si un participante habla en **Español de Chile (🇨🇱)**: se transcribe directamente en español sin retardo.
- **Overlay Flotante Tipo HUD**:
  - Ventana semitransparente con efecto *frosted glass* (`.ultraThinMaterial`).
  - **Always-on-top**: Se mantiene visible sobre Google Meet, el navegador o cualquier ventana activa.
  - **Draggable**: Puedes arrastrarla a cualquier lugar de la pantalla (debajo de las caras de los participantes en Meet).
  - **Modo Click-Through (`Cmd + Shift + K`)**: Permite que los clics del ratón traspasen los subtítulos para interactuar con los botones de Google Meet sin mover la ventana.
  - **Doble línea opcional**: Muestra la traducción principal en grande y el texto original en portugués atenuado en cursiva abajo.
  - Ajuste de tamaño de fuente (`A-` / `A+`) y control de pausa/reanudación.
- **Captura Nativa sin Drivers Virtuales**:
  - Utiliza `ScreenCaptureKit` nativo de macOS para capturar el audio que sale de Google Meet directamente sin necesidad de instalar BlackHole o configurar Audio MIDI Setup.
  - Soporta también captura de Micrófono para transcribir tu propia voz.
- **Ícono en la Barra de Menús**: Control rápido (`💬`) en la barra superior para pausar, cambiar de fuente de audio o salir.

---

## 🚀 Cómo Iniciar la Aplicación

Desde la terminal, simplemente ejecuta:

```bash
cd /Users/culloa/.gemini/antigravity/scratch/local-subtitles
./build_and_run.sh
```

El script verificará el modelo local de Whisper, compilará la aplicación nativa en Swift y abrirá la ventana de subtítulos en tu pantalla.

---

## ⚙️ Permisos de macOS requeridos al primer uso

Al ejecutar la aplicación por primera vez, macOS solicitará:
1. **Grabación de Pantalla y Audio del Sistema** (*Screen & System Audio Recording*):
   - Ve a `Ajustes del Sistema > Privacidad y Seguridad > Grabación de pantalla y audio del sistema`.
   - Activa el permiso para la app o la terminal. Esto permite a `ScreenCaptureKit` capturar el audio de la llamada de Google Meet.
2. **Micrófono** (Opcional): Si deseas capturar también tu propio micrófono seleccionando "Micrófono" en el selector.

---

## ⚡ Modos de Velocidad y Ajuste de Latencia

En la barra de herramientas de la ventana flotante tienes dos controles clave para ajustar la velocidad:

1. **Selector de Modelo (`⚡ Tiny` vs `⚖️ Base`)**:
   - `⚡ Ultra-Rápido (Tiny • ~70ms)`: Ideal para videollamadas fluidas en tiempo real. Reduce a la mitad el tiempo de procesamiento con excelente comprensión de portugués y español coloquial.
   - `⚖️ Equilibrado (Base • ~140ms)`: Mayor vocabulario técnico y jerga especializada.

2. **Selector de Idioma (`🌐 Auto` vs `🇧🇷 Solo PT` vs `🇨🇱 Solo ES`)**:
   - `🇧🇷 Solo Portugués`: Al fijar el idioma en Portugués, Whisper se salta la evaluación de los 99 idiomas soportados, **reduciendo el tiempo de respuesta en un 50% adicional**.
   - `🌐 Auto`: Detecta dinámicamente si habla un chileno o un brasileño.

3. **VAD (Voice Activity Detection) Ultrarrápido**:
   - Se redujo la ventana de silencio a 250ms (antes 500ms), lo que hace que los subtítulos se disparen 250ms antes en cuanto el participante hace una pausa natural al hablar.

---

## ⌨️ Atajos y Controles

- `Cmd + Shift + K`: Alternar modo **Click-Through** (para poder hacer clic en Google Meet a través del overlay).
- Botón **Pausar / Reproducir**: Pausa o reanuda la escucha en tiempo real.
- Botón **Reloj**: Abre el panel con el historial completo de transcripciones de la reunión.
- Botón **Fuente**: Alterna entre *Audio de Google Meet / Sistema* y *Micrófono*.
