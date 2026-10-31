# Epicycle Sketchbook

Draw any picture with Fourier epicycles. Load a photo or drawing, and the app:

1. **Isolates the subject (optional).** To ignore a busy background, it can cut out the person or object with on-device AI (MediaPipe body-part segmentation, or DeepLab-v3 for 20 everyday object classes). It can also remove a plain background with classical colour keying, use PNG transparency, or keep the whole image (no AI at all). This step only decides *what* to draw. It never draws lines.
2. **Draws the lines with computer vision.**
   * *Artist lines* (default for photos) use **Coherent Line Drawing** (Kang, Lee & Chui, 2007), written from scratch:
     1. A bilateral filter calms skin pores and fabric weave while keeping real edges.
     2. An **edge tangent flow** field records, for every pixel, the direction an edge through it runs, smoothed so neighbouring directions agree.
     3. A **flow-based difference of Gaussians** detects dark line structure across each edge, then averages it along the edge's own flow curve. Broken edge fragments join into long, continuous pen strokes, the way an artist draws them.
     4. A second pass with the first lines burned in closes the remaining gaps. Specks are removed, and the silhouette comes from the cut-out so it stays continuous.

     Every line (eyes, nose, smile lines, hair, folds, fingers) comes from the photo itself.
   * *Centerline* (drawings, logos, handwriting) thresholds the ink and skeletonizes it, so a pen stroke becomes one line instead of two edges.
   * *AI sketch* is a simplified style: outlines between hair, face, skin and clothes, plus template eyes, nose and lips placed by 478 face landmarks.
   * Every traced stroke is thinned to a 1‑px centerline, then simplified and smoothed (Douglas–Peucker, then Chaikin corner-cutting) so it reads as a calm, hand-drawn curve.
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
| Line style | Auto, Artist lines (computer vision), AI sketch, Centerline (ink drawings) |
| Outlines / Inner details / AI face features | switch each layer on or off |
| Detail | how many lines to keep: the share of the strongest line responses (or the ink threshold in centerline mode) |
| Smoothing | bilateral filter passes before drawing; more passes give calmer, fewer lines |
| Drop strokes shorter than | removes specks and texture noise |
| Working resolution | size the subject is traced at. The app crops to the subject first, so small figures still get full detail |
| Epicycles N | number of circles, from 1 to M−1 |
| Path samples M | DFT size. Auto picks about one sample per 1.5 px of path, from 1,024 to 8,192 |
| Playback | speed, circles, arms, dashed pen-lift lines, loop, follow-the-pen camera |
| Preview (button, `P`, or “Show the figure before it’s drawn”) | off by default: the figure appears only as the circles draw it. On: the whole N-term figure shows faintly in advance. Remembered per browser |

Keyboard: `Space` play/pause, `↑`/`↓` change N by 25%, `R` restart, `F` follow pen, `P` preview on/off. On the canvas: scroll to zoom, drag to pan, double-click to fit.

## Tips

* **Portraits:** leave everything on Auto. Keep the working resolution at 1024 px for half-body shots so the eyes resolve. If the drawing looks busy (patterned ties, textured fabric), lower *Detail* or raise *Smoothing*. If it looks bare, raise *Detail*.
* **No AI at all:** set Subject to *Whole* (or *Plain bg* for studio shots). The lines are always pure computer vision.
* **Crisper small features (eyes):** raise N. The error readout tells you how close the circles are to the sketch.
* **Line drawings, signatures, logos:** Line style → Centerline gives single clean strokes.
* **Busy photos without a person or known object:** try Plain bg, or Whole with low Detail.
* **Small N** shows the classic "blobby" approximation. Watch the error readout fall as you add circles.
* Pen lifts (jumps between strokes) are hidden by default. Turn on *Pen-lift lines* to see the whole single continuous path the circles actually trace.
