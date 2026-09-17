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

## ⚡ Modelos de Precisión y Velocidad

En la barra de herramientas de la ventana flotante puedes alternar entre 4 modelos según la dificultad de la reunión:

1. **`🎯 Small (Recomendado PT-BR • ~150ms)`** (465 MB):
   - **3.3x más grande que Base** (244M parámetros).
   - Diseñado específicamente para conversaciones reales en portugués de Brasil.
   - Entiende contracciones rápidas (*"pra gente"*, *"tá"*, *"cê"*, *"fechá"*) y modismos empresariales.
2. **`🏆 Large-v3-Turbo (Máxima Precisión • ~220ms)`** (1.6 GB):
   - **11x más grande que Base** (809M parámetros).
   - El modelo más avanzado de OpenAI con decoder Turbo de 4 capas.
   - Excelente para personas que hablan muy rápido, con acentos cerrados o sin modular.
3. **`⚖️ Base (Rápido • ~100ms)`** (141 MB):
   - Modelo intermedio para hardware más ajustado.
4. **`⚡ Tiny (Ultra-Rápido • ~70ms)`** (74 MB):
   - Para máxima velocidad cuando la pronunciación es clara y pausada.

### 🇧🇷 Contextual Prompting (Sesgo Inteligente PT-BR)
La app inyecta automáticamente un contexto previo en portugués brasileño (*"Reunião de negócios, alinhamento, prazos, orçamento, tá, pra gente, cê, beleza, combinado..."*), sesgando los pesos del modelo para que reconozca contracciones y jerga sin alucinaciones.

### ⏱️ VAD Calibrado para Habla Rápida
- **350ms de silencio** (evita cortar palabras a la mitad en pausas cortas).
- **1.2s de audio mínimo** (le entrega al transformador contexto suficiente para deducir palabras poco articuladas).

---

## ⌨️ Atajos y Controles

- `Cmd + Shift + K`: Alternar modo **Click-Through** (para poder hacer clic en Google Meet a través del overlay).
- Botón **Pausar / Reproducir**: Pausa o reanuda la escucha en tiempo real.
- Botón **Reloj**: Abre el panel con el historial completo de transcripciones de la reunión.
- Botón **Fuente**: Alterna entre *Audio de Google Meet / Sistema* y *Micrófono*.
