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
}class TakePictureScreenState extends State<TakePictureScreen> {

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
    // Your existing pixel counting logic remains here
    // ...
    return whitePixelsCount; // Make sure you have the correct return value based on your logic
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Your existing build method remains here
    // ...
  }
}