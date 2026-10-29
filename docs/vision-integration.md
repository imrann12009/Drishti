# DRISHTI vision integration

## What is implemented

- Android camera preview through the Flutter `camera` plugin.
- Android YUV420 camera-frame conversion to NV21.
- Mobile ML Kit base object detection in stream mode.
- 2-D labels, confidence values, and bounding boxes shown in the camera screen.
- Camera permission/error handling, app pause/resume controller disposal and
  reinitialization, image-stream cleanup, and detector-error handling.

## Explicit limitation

This is not a depth or navigation-safety model. A phone RGB camera plus 2-D
object detection does not establish physical distance, free space, stairs,
holes, moving-vehicle intent, or a safe crossing. The app therefore exposes
`depthMeters` as nullable and displays depth as unknown until an approved depth
sensor or validated depth model is integrated and benchmarked.

The current detector is a general ML Kit base detector. It is not trained for
Bangladeshi roads, rickshaws, drains, broken pavements, or the DRISHTI safety
classes. A production model requires a documented dataset, annotation policy,
train/validation/test split, false-negative analysis, latency measurement,
and supervised safety review.

## Android prerequisites

- Complete Flutter SDK and generated Android project.
- Android SDK requirements from the selected camera and ML Kit packages.
- Camera permission in the Android manifest.
- Device testing on the actual supported Android versions and camera hardware.

No camera data is uploaded by this code. Any future cloud processing must have
separate consent, retention, deletion, and security controls.

## What still requires a physical Android device

Automated tests cannot exercise Android permission denial, an unavailable
camera, real CameraX image-stream teardown, or ML Kit inference failure. Test
those cases on every supported device before release. The UI maps denied camera
permissions to Bengali guidance, surfaces camera/detector errors as failures,
and never substitutes a fake depth value: depth remains `অজানা` unless a
validated sensor/model is supplied.
