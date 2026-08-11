import 'dart:io';
import 'package:image/image.dart';

void main() {
  final inputPath = 'assets/images/logo.jpeg';
  final outputPath = 'assets/images/logo_padded.png';

  final bytes = File(inputPath).readAsBytesSync();
  final image = decodeImage(bytes);

  if (image == null) {
    throw Exception('Could not read image');
  }

  // We want to add significant padding. Let's make the canvas larger by 50%.
  // So if image is WxH, new canvas is 1.5W x 1.5H.
  final newWidth = (image.width * 1.5).round();
  final newHeight = (image.height * 1.5).round();

  // Create a new image with white background
  final newImage = Image(width: newWidth, height: newHeight);
  // Fill with white
  fill(newImage, color: ColorRgb8(255, 255, 255));

  // Draw the original image into the center
  final dstX = (newWidth - image.width) ~/ 2;
  final dstY = (newHeight - image.height) ~/ 2;

  compositeImage(newImage, image, dstX: dstX, dstY: dstY);

  // Save as PNG
  File(outputPath).writeAsBytesSync(encodePng(newImage));
  // File written successfully
}
