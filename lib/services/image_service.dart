import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../config/app_config.dart';
import '../utils/app_exceptions.dart';

/// Сервис для подготовки изображений расклада к отправке в Vision API.
/// Обрабатывает размер, сжатие и получение bytes.
abstract class ImageService {
  /// Подготавливает изображение: читает bytes, проверяет размер, сжимает при нужде.
  Future<Uint8List> prepareImage(String imagePath);
}

/// Реализация на базе пакета image для resize и compression.
class ImageServiceImpl implements ImageService {
  @override
  Future<Uint8List> prepareImage(String imagePath) async {
    try {
      // 1. Проверяем существование файла
      final File file = File(imagePath);
      if (!file.existsSync()) {
        throw AppException('Файл изображения не найден');
      }

      // 2. Читаем исходные bytes
      final Uint8List originalBytes = await file.readAsBytes();

      // 3. Проверяем начальный размер
      if (originalBytes.lengthInBytes > AppConfig.maxImageBytes) {
        throw ImageTooLargeException();
      }

      // 4. Декодируем изображение
      final img.Image? originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        throw AppException('Не удалось декодировать изображение');
      }

      // 5. Ресайзим, если слишком большое (макс 1920x1920 для Vision API)
      img.Image processedImage = originalImage;
      if (originalImage.width > 1920 || originalImage.height > 1920) {
        processedImage = img.copyResize(
          originalImage,
          width: 1920,
          height: 1920,
          interpolation: img.Interpolation.linear,
        );
      }

      // 6. Сжимаем в JPEG (качество 85 - хороший баланс)
      Uint8List compressed = Uint8List.fromList(
        img.encodeJpg(processedImage, quality: 85),
      );

      // 7. Если ещё слишком большое - агрессивнее сжимаем
      if (compressed.lengthInBytes > AppConfig.maxImageBytes) {
        compressed = Uint8List.fromList(
          img.encodeJpg(processedImage, quality: 70),
        );
      }

      // 8. Финальная проверка
      if (compressed.lengthInBytes > AppConfig.maxImageBytes) {
        throw ImageTooLargeException();
      }

      return compressed;
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Ошибка обработки изображения: $e');
    }
  }
}
