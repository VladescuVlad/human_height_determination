import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(camera: firstCamera),
    ),
  );
}

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;

  const TakePictureScreen({required this.camera});

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int _backgroundPixelsCount = 0;
  int _countLinePixelsPixelsCount = 0; // Second counter for demonstration

  // Frame processing control
  int _frameCounter = 0;
  final int _processEveryNthFrame = 15; // Adjust this value as needed

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420, // Optimized for real-time processing
    );
    _initializeControllerFuture = _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.startImageStream((CameraImage image) {
        // Increment frame counter
        _frameCounter++;

        // Process only every nth frame
        if (_frameCounter % _processEveryNthFrame == 0) {
          final int backgroundPixelCount = _countDarkPixels(image);
          final int countLinePixelsyPixelCount = _estimateRealWorldHeight(image); // Dummy calculation for the second counter
          setState(() {
            _backgroundPixelsCount = backgroundPixelCount;
            _countLinePixelsPixelsCount = countLinePixelsyPixelCount; // Update the state for the second counter
          });

          // Reset frame counter to avoid overflow (optional)
          if (_frameCounter >= 10000) {
            _frameCounter = 0;
          }
        }
      });
    });
  }

  int _countWhitePixels(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    // Assuming YUV420 format.
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    // The YUV420 format usually has half the U and V values, which are shared across pixels.
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel!;

    int whitePixelsCount = 0;

    // Simple threshold to consider a pixel white
    const int whiteThreshold = 200;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int ypIndex = y * yPlane.bytesPerRow + x;
        final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        // Extract YUV values
        final int yp = yPlane.bytes[ypIndex];
        final int up = uPlane.bytes[uvIndex];
        final int vp = vPlane.bytes[uvIndex];

        // Convert YUV to RGB
        final num r = (yp + vp * 1436 / 1024 - 179).clamp(0, 255);
        final num g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).clamp(0, 255);
        final num b = (yp + up * 1814 / 1024 - 227).clamp(0, 255);

        // Check if the pixel is considered white
        if (r > whiteThreshold && g > whiteThreshold && b > whiteThreshold) {
          whitePixelsCount++;
        }
      }
    }

    return whitePixelsCount;
  }

  int _estimateRealWorldHeight(CameraImage image) {
    final List<int> rgbSpectrum = calculateRGBSpectrum(image);
    // Use the average RGB values to determine the threshold for dark pixels
    final int backgroundThreshold = (rgbSpectrum.reduce((a, b) => a + b) / 3).toInt();

    final int width = image.width;
    final int height = image.height;
    bool countedBackgroundPixelsTopToA4 = false;

    // Assuming YUV420 format.
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    // The YUV420 format usually has half the U and V values, which are shared across pixels.
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel!;

    int backgroundPixelColorCount = 0;
    int humanPixelColorCount = 0;
    int a4PixelColorCount = 0;
    bool startedHumanRead = false;

    num rPreviewsBackgroundColor = 0;
    num gPreviewBackgroundColor = 0;
    num bPreviewBackgroundColor = 0;


    for (int x = 0; x < width; x++) {
      final int ypIndex = (height ~/ 2) * yPlane.bytesPerRow + x;
      final int uvIndex = ((height ~/ 2) ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

      // Extract YUV values
      final int yp = yPlane.bytes[ypIndex];
      final int up = uPlane.bytes[uvIndex];
      final int vp = vPlane.bytes[uvIndex];

      // Convert YUV to RGB
      final num r = (yp + vp * 1436 / 1024 - 179).clamp(0, 255);
      final num g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).clamp(0, 255);
      final num b = (yp + up * 1814 / 1024 - 227).clamp(0, 255);


      num prevAndCurrentRgbDifferenceR = rPreviewsBackgroundColor - r;
      num prevAndCurrentRgbDifferenceG = gPreviewBackgroundColor - g;
      num prevAndCurrentRgbDifferenceB = bPreviewBackgroundColor - b;

      if(!startedHumanRead){
        if(prevAndCurrentRgbDifferenceR > 50 && prevAndCurrentRgbDifferenceG > 50 && prevAndCurrentRgbDifferenceB > 50 ){
          if (r < 169 && g < 169 && b < 169 ) {
            humanPixelColorCount++;

          }else{
            a4PixelColorCount++;
            humanPixelColorCount++;
          }
          startedHumanRead = true;
        }else{
          rPreviewsBackgroundColor = r;
          gPreviewBackgroundColor = g;
          bPreviewBackgroundColor = b;
        }

      }else{
        if (r < 169 && g < 169 && b < 169 ) {
          humanPixelColorCount++;

        }else{
          a4PixelColorCount++;
          humanPixelColorCount++;
        }
      }
    }

    // Estimate the real-world height based on the number of pixels representing the human figure
    // a4PixelColorCount = (a4PixelColorCount /210).toInt();
    humanPixelColorCount = humanPixelColorCount*210 ;
    final int estimateHeight  = (humanPixelColorCount/ a4PixelColorCount/10-10).toInt();
    return estimateHeight;
  }

  int _remakeEstimation(CameraImage image) {
    final List<int> rgbSpectrum = calculateRGBSpectrum(image);

    // Use the average RGB values to determine the threshold for dark pixels
    final int threshold = (rgbSpectrum.reduce((a, b) => a + b) / 3).toInt();

    final int width = image.width;
    final int height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel!;

    int darkPixelsCount = 0;
    int middle = (width / 2).toInt();

    List<List<int>> objectMatrix = []; // Matrix to store object pixels

    for (int y = 0; y < height; y++) {
      List<int> rowValues = [];
      for (int x = 0; x < width; x++) {

        final int ypIndex = y * yPlane.bytesPerRow + x;
        final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final int yp = yPlane.bytes[ypIndex];
        final int up = uPlane.bytes[uvIndex];
        final int vp = vPlane.bytes[uvIndex];

        final num r = (yp + vp * 1436 / 1024 - 179).clamp(0, 255);
        final num g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).clamp(0, 255);
        final num b = (yp + up * 1814 / 1024 - 227).clamp(0, 255);

        if (r > 170 && g > 170 && b > 170) {
          rowValues.add(0); // Background pixel
        } else {
          rowValues.add(1); // Object pixel
        }

        if (y == middle) {
          // Check if the pixel is considered dark based on the threshold
          if (r > 170 && g > 170 && b > 170) {
            darkPixelsCount++;
          }
        }
      }
      objectMatrix.add(rowValues); // Add the row to the matrix
    }

    // Print the objectMatrix in the console
    print('Object Matrix:');
    for (var row in objectMatrix) {
      print(row);
    }

    return darkPixelsCount;
  }


  int _countDarkPixels(CameraImage image) {
    final List<int> rgbSpectrum = calculateRGBSpectrum(image);

    // Use the average RGB values to determine the threshold for dark pixels
    final int threshold = (rgbSpectrum.reduce((a, b) => a + b) / 3).toInt();

    final int width = image.width;
    final int height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel!;

    int darkPixelsCount = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int ypIndex = y * yPlane.bytesPerRow + x;
        final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final int yp = yPlane.bytes[ypIndex];
        final int up = uPlane.bytes[uvIndex];
        final int vp = vPlane.bytes[uvIndex];

        final num r = (yp + vp * 1436 / 1024 - 179).clamp(0, 255);
        final num g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).clamp(0, 255);
        final num b = (yp + up * 1814 / 1024 - 227).clamp(0, 255);

        // Check if the pixel is considered dark based on the threshold
        if (r < threshold && g < threshold && b < threshold) {
          darkPixelsCount++;
        }
      }
    }

    return darkPixelsCount;
  }
  List<int> calculateRGBSpectrum(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel!;

    int rSum = 0, gSum = 0, bSum = 0, pixelCount = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int ypIndex = y * yPlane.bytesPerRow + x;
        final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final int yp = yPlane.bytes[ypIndex];
        final int up = uPlane.bytes[uvIndex];
        final int vp = vPlane.bytes[uvIndex];

        final num r = (yp + vp * 1436 / 1024 - 179).clamp(0, 255);
        final num g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).clamp(0, 255);
        final num b = (yp + up * 1814 / 1024 - 227).clamp(0, 255);

        rSum += r.toInt();
        gSum += g.toInt();
        bSum += b.toInt();
        pixelCount++;
      }
    }

    final int avgR = (rSum / pixelCount).toInt();
    final int avgG = (gSum / pixelCount).toInt();
    final int avgB = (bSum / pixelCount).toInt();

    return [avgR, avgG, avgB];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fit red square in background')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CameraPreview(_controller),
                Positioned(
                  top: 90,
                  child: Text(
                    'Background Pixels: $_backgroundPixelsCount',
                    style: TextStyle(color: Colors.white, backgroundColor: Colors.black54),
                  ),
                ),
                Positioned(
                  bottom: 80,
                  child: Text(
                    'Height : $_countLinePixelsPixelsCount'+" cm",
                    style: TextStyle(color: Colors.white, backgroundColor: Colors.black54),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.369 - 69, // yellow square moves up from bottom to top when  last - number increased Center vertically
                  left: MediaQuery.of(context).size.width * 0.5 - 50, // yellow square moves up from left to right when  last - number increased
                  child: Container(
                    width: 100,
                    height: 69,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 1.0),
                    ),
                  ),
                ),
                CustomPaint(
                  size: Size.infinite,
                  painter: LinePainter(
                    startY: 123,
                    endY: MediaQuery.of(context).size.height-200,
                    color: Colors.yellow,
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.369 +330, // yellow square moves up from bottom to top when  last - number increased Center vertically
                  left: MediaQuery.of(context).size.width * 0.5 - 80, // yellow square moves up from left to right when  last - number increased
                  child: Container(
                    width: 169,
                    height: 3,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 3.0),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  final double startY;
  final double endY;
  final Color color;

  LinePainter({required this.startY, required this.endY, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(size.width / 2, startY), Offset(size.width / 2, endY), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class HorizontalLinePainter extends CustomPainter {
  final double startX;
  final double endX;
  final Color color;

  HorizontalLinePainter({required this.startX, required this.endX, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(startX, size.height), Offset(endX, size.height), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
