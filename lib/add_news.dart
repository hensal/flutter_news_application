import 'dart:typed_data';
import 'dart:io' show File;
import 'package:demo_app/service/news_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:image/image.dart' as img; 

/// Bottom sheet widget with a form to add news.
class AddNewsSheet extends StatefulWidget {
  const AddNewsSheet({super.key});

  @override
  _AddNewsSheetState createState() => _AddNewsSheetState();
}

class _AddNewsSheetState extends State<AddNewsSheet> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  // For mobile, we use a File; on web, we store bytes.
  File? _pickedImage;
  Uint8List? _pickedImageBytes;

  final NewsService _newsService = NewsService(); // Corrected class name

  // Function to compress image before sending
  Future<Uint8List?> compressImage(Uint8List imageBytes) async {
    // Decode the image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return null;

    // Compress the image
    img.Image compressedImage = img.copyResize(image, width: 800); // Resize as needed
    return img.encodeJpg(compressedImage, quality: 85); // Adjust quality to reduce size
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null) {
      setState(() {
        _pickedImageBytes = result.files.single.bytes;
      });

      // Compress the image if it was picked
      if (_pickedImageBytes != null) {
        _pickedImageBytes = await compressImage(_pickedImageBytes!);  // Compress the image
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Padding ensures the bottom sheet adjusts for the keyboard.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Add News",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Category Field
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Image Picker Field
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _pickedImageBytes != null
                      ? Image.memory(
                          _pickedImageBytes!,
                          fit: BoxFit.cover,
                        )
                      : _pickedImage != null
                          ? Image.file(
                              _pickedImage!,
                              fit: BoxFit.cover,
                            )
                          : const Center(child: Text("Tap to select image")),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      await _newsService.addNews(
                        title: _titleController.text,
                        description: _descriptionController.text,
                        category: _categoryController.text,
                        imageBytes: _pickedImageBytes,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("News added successfully")),
                      );
                      Navigator.of(context).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to add news: $e")),
                      );
                    }
                  }
                },
                child: const Text("Submit"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
