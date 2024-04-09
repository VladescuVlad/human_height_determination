import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

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
  int _whitePixelsCount = 0;

  // Frame processing control
  int _frameCounter = 0;
  final int _processEveryNthFrame = 5; // Adjust this value as needed

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
          final int whitePixelCount = _countWhitePixels(image);
          setState(() {
            _whitePixelsCount = whitePixelCount;
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


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Display the Picture')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CameraPreview(_controller),
                Positioned(
                  top: 160,
                  child: Container(
                    width: 110,
                    height: 70,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2.0),
                    ),
                    child: Center(
                      child: Text(
                        'White Pixels: $_whitePixelsCount',
                        style: TextStyle(color: Colors.white),
                      ),
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
