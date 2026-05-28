import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FilePickerButton extends StatelessWidget {
  final Function(PlatformFile) onFileSelected;

  const FilePickerButton({
    super.key,
    required this.onFileSelected,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _pickFile(context),
      icon: const Icon(Icons.attach_file),
      tooltip: 'Attach File',
      style: IconButton.styleFrom(
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.grey[700],
      ),
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Check file size (10MB limit)
        if (file.size > 10 * 1024 * 1024) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File size exceeds 10MB limit'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Check file type
        if (!_isAllowedFileType(file.extension)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File type not allowed'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        onFileSelected(file);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isAllowedFileType(String? extension) {
    if (extension == null) return false;
    
    final allowedExtensions = [
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', // Images
      'pdf', 'doc', 'docx', 'txt', 'rtf', // Documents
      'xls', 'xlsx', 'csv', // Spreadsheets
      'ppt', 'pptx', // Presentations
      'zip', 'rar', '7z', // Archives
    ];
    
    return allowedExtensions.contains(extension.toLowerCase());
  }
}
