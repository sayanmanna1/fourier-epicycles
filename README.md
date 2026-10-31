# Epicycle Sketchbook

Draw any picture with Fourier epicycles. Load a photo or drawing, and the app:

1. **Isolates the subject.** For photos it uses on-device AI (MediaPipe): a body-part model that labels hair, face, skin and clothes, and DeepLab-v3 for 20 everyday object classes. It can also remove a plain background, use PNG transparency, or keep the whole image.
2. **Extracts the lines.**
   * *Sketch* (people, the default for photos of people) draws the way an artist does:
     * Outlines are the borders between hair, face, neck and hands, and clothes, so you get the hairline, jaw, ears, collar and sleeves as clean curves.
     * Eyes (with irises), eyebrows, nose and lips come from 478 face landmarks and are drawn as smooth curves. No edge noise ever lands on the face.
     * The rest is only the strongest, longest edges: suit lapels, folds, and fingers (hands get a closer look).
   * *Edges* (other photos): Canny edge detection inside the subject, plus the subject's outline.
   * *Centerline* (drawings, logos, handwriting): thresholds the ink and skeletonizes it, so a pen stroke becomes one line instead of two edges.
   * Every traced stroke is simplified and smoothed (Douglas–Peucker, then Chaikin corner-cutting) so it reads as a calm, hand-drawn curve rather than a pixel staircase.
3. **Turns the lines into one closed path.** It traces the 1‑px skeleton into strokes, orders them with nearest-neighbour plus 2‑opt to keep pen lifts short, and joins them.
4. **Takes the DFT.** The path is resampled to M evenly spaced complex points `z = x + iy` and run through an FFT: `c_k = (1/M) Σ z_n e^{-2πi kn/M}`.
5. **Animates N epicycles.** The coefficients are sorted by radius `|c_k|`. The N largest are chained tip to tail, each turning `k` times per drawing, and the last tip traces `z(t) = Σ c_k e^{2πi k t}`.

You pick **N** with the slider (log scale), the number box or the presets. The drawing morphs live because the N-term curve is rebuilt with an inverse FFT. The panel shows the **average error in pixels**, which comes straight from Parseval's theorem (`√Σ|c_k|²` over the dropped terms), and an amplitude spectrum that highlights the terms in use.

## Run it

AI segmentation loads WebAssembly and model files, so the page has to be served over HTTP. Opening it as a `file://` URL does not work.

```bash
cd fourier-epicycles
python3 -m http.server 8000
```

Then open http://localhost:8000. Any static server works (`npx serve`, nginx, GitHub Pages, …).

Everything runs in the browser. Nothing is uploaded anywhere.

## Files

```
index.html                      the whole app (HTML + CSS + JS, no build step)
vendor/vision_bundle.js         @mediapipe/tasks-vision 0.10.14 (Apache-2.0)
vendor/wasm/…                   MediaPipe WebAssembly runtime
vendor/models/selfie_multiclass_256x256.tflite  hair / face / skin / clothes segmentation (~16 MB)
vendor/models/face_landmarker.task      478-point face landmarks (~3.7 MB)
vendor/models/selfie_segmenter.tflite   person segmentation, fallback (~250 KB)
vendor/models/deeplab_v3.tflite         object segmentation (~2.8 MB)
fetch-vendor.sh                 re-downloads the vendor/ folder
```

If `vendor/` is missing, run `./fetch-vendor.sh` (needs `npm` and `curl`). Without it the app still works, but **Subject → Auto** falls back to plain-background detection.

## Controls

| Control | What it does |
|---|---|
| Subject | Auto, Person (AI), Object (AI), Plain bg, Whole image |
| Line style | Auto, Sketch (people), Edges, Centerline (ink drawings) |
| Outlines / Inner details / Face features | switch each layer of the sketch on or off |
| Detail | how many folds and edges to keep (or the ink threshold in centerline mode) |
| Smoothing | Gaussian blur σ before edge detection |
| Drop strokes shorter than | removes specks and texture noise |
| Working resolution | size the subject is traced at. The app crops to the subject first, so small figures still get full detail |
| Epicycles N | number of circles, from 1 to M−1 |
| Path samples M | DFT size. Auto picks about one sample per 2 px of line |
| Playback | speed, circles, arms, preview of the final N-term curve, dashed pen-lift lines, loop, follow-the-pen camera |

Keyboard: `Space` play/pause, `↑`/`↓` change N by 25%, `R` restart, `F` follow pen. On the canvas: scroll to zoom, drag to pan, double-click to fit.

## Tips

* **Portraits:** leave everything on Auto. Faces looking at the camera (or roughly toward it) get landmark eyes, nose and mouth. Faces in full profile only get their outline. If the clothes look busy, lower *Detail* or raise *Drop strokes shorter than*. If they look bare, raise *Detail*.
* **Crisper small features (eyes):** raise N. The error readout tells you how close the circles are to the sketch.
* **Line drawings, signatures, logos:** Line style → Centerline gives single clean strokes.
* **Busy photos without a person or known object:** try Plain bg, or Whole with low Detail.
* **Small N** shows the classic "blobby" approximation. Watch the error readout fall as you add circles.
* Pen lifts (jumps between strokes) are hidden by default. Turn on *Pen-lift lines* to see the whole single continuous path the circles actually trace.
