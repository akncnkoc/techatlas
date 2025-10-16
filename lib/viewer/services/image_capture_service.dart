import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ImageCaptureService {
  /// Seçili alanı transform'a göre düzelt ve crop et
  static Future<Uint8List?> captureSelectedArea({
    required GlobalKey canvasKey,
    required Rect selectedRect,
  }) async {
    try {
      final boundary =
          canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        print('❌ Canvas boundary bulunamadı');
        return null;
      }

      // RenderBox boyutunu al
      final renderBox = canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        print('❌ RenderBox bulunamadı');
        return null;
      }

      final viewportSize = renderBox.size;
      print('📱 Viewport boyutu: ${viewportSize.width} x ${viewportSize.height}');

      print(
        '📐 Kullanıcının seçtiği alan (viewport): x=${selectedRect.left.toInt()}, y=${selectedRect.top.toInt()}, w=${selectedRect.width.toInt()}, h=${selectedRect.height.toInt()}',
      );

      // Screenshot al - viewport boyutunda
      final pixelRatio = 4.0;
      print('📸 Screenshot alınıyor (pixelRatio: $pixelRatio)...');

      final fullImage = await boundary.toImage(pixelRatio: pixelRatio);
      print('🖼️ Screenshot boyutu: ${fullImage.width} x ${fullImage.height}');

      // Gerçek scale faktörü (screenshot boyutu / viewport boyutu)
      final actualScaleX = fullImage.width / viewportSize.width;
      final actualScaleY = fullImage.height / viewportSize.height;

      print('📏 Scale faktörleri: X=$actualScaleX, Y=$actualScaleY');

      // Seçili alanı scale et
      final scaledLeft = selectedRect.left * actualScaleX;
      final scaledTop = selectedRect.top * actualScaleY;
      final scaledWidth = selectedRect.width * actualScaleX;
      final scaledHeight = selectedRect.height * actualScaleY;

      print(
        '✂️ Scaled crop area: x=${scaledLeft.toInt()}, y=${scaledTop.toInt()}, w=${scaledWidth.toInt()}, h=${scaledHeight.toInt()}',
      );

      // Sınırları clamp et
      final clampedLeft = scaledLeft.clamp(0.0, fullImage.width.toDouble());
      final clampedTop = scaledTop.clamp(0.0, fullImage.height.toDouble());
      final clampedRight = (scaledLeft + scaledWidth).clamp(
        0.0,
        fullImage.width.toDouble(),
      );
      final clampedBottom = (scaledTop + scaledHeight).clamp(
        0.0,
        fullImage.height.toDouble(),
      );

      final finalWidth = (clampedRight - clampedLeft).toInt();
      final finalHeight = (clampedBottom - clampedTop).toInt();

      print(
        '🎯 Final crop (clamped): x=${clampedLeft.toInt()}, y=${clampedTop.toInt()}, w=$finalWidth, h=$finalHeight',
      );

      // Geçerlilik kontrolü
      if (finalWidth < 10 || finalHeight < 10) {
        print('❌ Crop alanı çok küçük: ${finalWidth}x$finalHeight');
        fullImage.dispose();
        return null;
      }

      // Crop rectangle
      final cropRect = Rect.fromLTWH(
        clampedLeft,
        clampedTop,
        finalWidth.toDouble(),
        finalHeight.toDouble(),
      );

      // Yeni image oluştur
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Arka planı beyaz yap
      canvas.drawRect(
        Rect.fromLTWH(0, 0, finalWidth.toDouble(), finalHeight.toDouble()),
        Paint()..color = Colors.white,
      );

      // Crop edilen bölgeyi çiz
      canvas.drawImageRect(
        fullImage,
        cropRect,
        Rect.fromLTWH(0, 0, finalWidth.toDouble(), finalHeight.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();

      // Eğer görsel çok küçükse, upscale yap
      final minDimension = 1200; // Minimum boyut
      int outputWidth = finalWidth;
      int outputHeight = finalHeight;

      if (finalWidth < minDimension || finalHeight < minDimension) {
        final scale =
            minDimension / (finalWidth < finalHeight ? finalWidth : finalHeight);
        outputWidth = (finalWidth * scale).toInt();
        outputHeight = (finalHeight * scale).toInt();
        print(
          '📈 Upscaling: ${finalWidth}x$finalHeight → ${outputWidth}x$outputHeight',
        );
      }

      final croppedImage = await picture.toImage(outputWidth, outputHeight);

      print(
        '✅ Cropped image oluşturuldu: ${croppedImage.width} x ${croppedImage.height}',
      );

      // PNG'ye dönüştür
      final byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      // Cleanup
      fullImage.dispose();
      croppedImage.dispose();

      final result = byteData?.buffer.asUint8List();

      if (result != null) {
        print('💾 PNG boyutu: ${(result.length / 1024).toStringAsFixed(1)} KB');

        // Debug: Görseli kaydet
        try {
          final downloadsPath = '/Users/${Platform.environment['USER']}/Downloads';
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final debugFile = File('$downloadsPath/debug_crop_$timestamp.png');
          await debugFile.writeAsBytes(result);
          print('🔍 Debug: Görsel kaydedildi → ${debugFile.path}');
          print('👁️ Görseli açıp doğru kesilip kesilmediğini kontrol edin!');
        } catch (e) {
          print('⚠️ Debug kayıt hatası: $e');
        }
      }

      return result;
    } catch (e, stackTrace) {
      print('❌ Crop hatası: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}
