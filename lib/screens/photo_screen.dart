import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../models/person.dart';
import '../services/image_service.dart';
import '../utils/app_exceptions.dart';

/// Экран для выбора фотографии расклада.
/// Позволяет сделать фото через камеру или выбрать из галереи.
/// После выбора показывает превью и обрабатывает изображение.
class PhotoScreen extends StatefulWidget {
  const PhotoScreen({
    super.key,
    required this.question,
    required this.person,
    required this.onPhotoSelected,
  });

  final String question;
  final Person person;
  final void Function(Uint8List imageBytes, String originalPath) onPhotoSelected;

  @override
  State<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends State<PhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  late ImageService _imageService;
  File? _selectedImage;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _imageService = ImageServiceImpl();
  }

  Future<void> _takePhoto() async {
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95, // Сохраняем качество, обработаем потом
      );

      if (image == null) {
        // Пользователь отменил
        setState(() => _isProcessing = false);
        return;
      }

      _validateAndSelectImage(File(image.path));
    } on Exception catch (_) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Не удалось открыть камеру.\n'
            'Проверьте разрешения приложения и попробуйте снова.';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) {
        // Пользователь отменил
        setState(() => _isProcessing = false);
        return;
      }

      _validateAndSelectImage(File(image.path));
    } on Exception catch (_) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Не удалось открыть галерею.\n'
            'Проверьте разрешения приложения и попробуйте снова.';
      });
    }
  }

  Future<void> _validateAndSelectImage(File file) async {
    try {
      // Проверяем существование файла
      if (!file.existsSync()) {
        throw const AppException('Файл изображения не найден.');
      }

      // Проверяем размер файла
      final int fileSize = await file.length();
      if (fileSize > AppConfig.maxImageBytes) {
        throw const ImageTooLargeException();
      }

      setState(() => _selectedImage = file);
    } on AppException catch (e) {
      setState(() {
        _errorMessage = '$e';
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Не удалось прочитать изображение.\n'
            'Попробуйте выбрать другое фото.';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _proceedToAnalysis() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Подготавливаем изображение
      final Uint8List imageBytes = await _imageService.prepareImage(
        _selectedImage!.path,
      );

      // Передаём в следующий экран
      widget.onPhotoSelected(imageBytes, _selectedImage!.path);
    } on AppException catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = '$e';
      });
    } catch (_) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Не удалось обработать фотографию.\n'
            'Попробуйте сделать снимок заново.';
      });
    }
  }

  /// Короткая инструкция перед съёмкой.
  ///
  /// Последний пункт важен для определения upright/reversed: поворот
  /// фотографии после съёмки ломает ориентацию карт.
  Widget _buildPhotoTips(ThemeData theme) {
    const List<String> tips = <String>[
      'Разложите карты полностью в пределах кадра.',
      'Фотографируйте сверху, по возможности без сильного наклона.',
      'Следите, чтобы карты не перекрывали друг друга.',
      'Избегайте бликов и слишком тёмного освещения.',
      'Не обрезайте края карт.',
      'Для карт в один ряд горизонтальный кадр обычно удобнее. '
          'Для вертикального расклада используйте вертикальный кадр.',
      'Не поворачивайте фотографию после съёмки.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.goldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldEdge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.lightbulb_outline,
                  size: 18, color: AppTheme.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Как лучше сфотографировать расклад',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final String tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '\u2022 ',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppTheme.gold),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppTheme.textSoft),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Покажите свой расклад'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Разложите карты и сфотографируйте их так, чтобы все карты '
              'были хорошо видны.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _buildPhotoTips(theme),
            const SizedBox(height: 28),
            // Сообщение об ошибке
            if (_errorMessage != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A0000),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF5252),
                    width: 1,
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFF5252),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Выбор фото или превью
            if (_selectedImage == null) ...<Widget>[
              FilledButton.icon(
                onPressed: _isProcessing ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Сделать фотографию'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _pickFromGallery,
                icon: const Icon(Icons.image),
                label: const Text('Выбрать из галереи'),
              ),
            ] else ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _selectedImage!,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isProcessing ? null : _proceedToAnalysis,
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Анализировать расклад'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isProcessing
                    ? null
                    : () {
                        setState(() {
                          _selectedImage = null;
                          _errorMessage = null;
                        });
                      },
                child: const Text('Выбрать другое фото'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
