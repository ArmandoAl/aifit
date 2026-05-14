import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/wardrobe_repository_impl.dart';
import '../bloc/wardrobe_bloc.dart';
import '../bloc/wardrobe_event.dart';

class AddWardrobeItemPage extends StatefulWidget {
  final List<File>? initialImages;

  const AddWardrobeItemPage({
    super.key,
    this.initialImages,
  });

  @override
  State<AddWardrobeItemPage> createState() => _AddWardrobeItemPageState();
}

class _AddWardrobeItemPageState extends State<AddWardrobeItemPage> {
  final ImagePicker _picker = ImagePicker();
  final WardrobeRepositoryImpl _repository = WardrobeRepositoryImpl();
  
  final List<File> _selectedImages = [];
  final List<ItemFormData> _formDataList = [];
  
  bool _isUploading = false;

  // Clothing type options
  static const List<String> _clothingTypes = [
    'top',
    'bottom',
    'shoes',
    'outerwear',
  ];

  // Sub-type options by main type
  static const Map<String, List<String>> _subTypes = {
    'top': ['t-shirt', 'shirt', 'sweater', 'hoodie', 'tank-top', 'blouse'],
    'bottom': ['jeans', 'pants', 'shorts', 'skirt', 'chinos', 'sweatpants'],
    'shoes': ['sneakers', 'boots', 'sandals', 'dress-shoes', 'sports-shoes'],
    'outerwear': ['jacket', 'coat', 'blazer', 'cardigan', 'vest'],
  };

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 AddWardrobeItemPage initState');
    debugPrint('   - initialImages: ${widget.initialImages?.length ?? 0}');
    debugPrint('   - initialImages is null: ${widget.initialImages == null}');
    
    if (widget.initialImages != null && widget.initialImages!.isNotEmpty) {
      for (var img in widget.initialImages!) {
        debugPrint('   - Image path: ${img.path}');
        debugPrint('   - Image exists: ${img.existsSync()}');
      }
      
      _selectedImages.addAll(widget.initialImages!);
      _formDataList.addAll(
        widget.initialImages!.map((_) => ItemFormData()),
      );
      debugPrint('✅ Initialized with ${_selectedImages.length} images');
    } else {
      debugPrint('⚠️ No initial images provided - showing empty state');
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((x) => File(x.path)));
        _formDataList.addAll(
          images.map((_) => ItemFormData()),
        );
      });
    }
  }


  bool _validateForms() {
    for (int i = 0; i < _formDataList.length; i++) {
      if (_formDataList[i].type == null || _formDataList[i].subType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill all required fields for item ${i + 1}'),
            backgroundColor: AppColors.error,
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _saveItems() async {
    debugPrint('💾 Save button pressed');
    debugPrint('   - Images: ${_selectedImages.length}');
    debugPrint('   - Form data: ${_formDataList.length}');
    
    if (!_validateForms()) {
      debugPrint('❌ Form validation failed');
      return;
    }
    
    debugPrint('✅ Form validation passed');

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add items'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final formData = _formDataList[i];

        // Upload image and save to Firestore
        await _repository.addWardrobeItemWithData(
          imageFile: image,
          type: formData.type!,
          subType: formData.subType!,
          brand: formData.brand,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Items added successfully! 🎉'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        // Refresh wardrobe list
        context.read<WardrobeBloc>().add(const WardrobeItemAdded());

        // Close page
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding items: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ AddWardrobeItemPage build - images: ${_selectedImages.length}');
    final isSingleItem = _selectedImages.length == 1;
    debugPrint('🏗️ Is single item: $isSingleItem');

    return Scaffold(
      appBar: AppBar(
        title: Text(isSingleItem ? 'Add Item' : 'Add Items (${_selectedImages.length})'),
        actions: [
          if (_selectedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _isUploading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: _saveItems,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
            ),
        ],
      ),
      body: _selectedImages.isEmpty
          ? _buildEmptyState()
          : (isSingleItem ? _buildSingleItemForm() : _buildMultipleItemsForm()),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No images selected',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.photo_library),
            label: const Text('Select Images'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleItemForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Image preview
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: FileImage(_selectedImages[0]),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Form
          _buildItemForm(0),
        ],
      ),
    );
  }

  Widget _buildMultipleItemsForm() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _selectedImages.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image preview
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(_selectedImages[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Micro form
                _buildItemForm(index, isCompact: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemForm(int index, {bool isCompact = false}) {
    final formData = _formDataList[index];
    final subTypeOptions = formData.type != null
        ? (_subTypes[formData.type] ?? [])
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCompact) ...[
          Text(
            'Item Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Type dropdown
        DropdownButtonFormField<String>(
          value: formData.type,
          decoration: const InputDecoration(
            labelText: 'Type *',
            border: OutlineInputBorder(),
          ),
          items: _clothingTypes.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type[0].toUpperCase() + type.substring(1)),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              formData.type = value;
              formData.subType = null; // Reset subType when type changes
            });
          },
        ),
        const SizedBox(height: 16),
        // Sub-type dropdown
        DropdownButtonFormField<String>(
          value: formData.subType,
          decoration: const InputDecoration(
            labelText: 'Sub-type *',
            border: OutlineInputBorder(),
          ),
          items: subTypeOptions.map((subType) {
            return DropdownMenuItem(
              value: subType,
              child: Text(subType[0].toUpperCase() + subType.substring(1)),
            );
          }).toList(),
          onChanged: formData.type == null
              ? null
              : (value) {
                  setState(() {
                    formData.subType = value;
                  });
                },
        ),
        const SizedBox(height: 16),
        // Brand (optional)
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Brand (optional)',
            border: OutlineInputBorder(),
          ),
          initialValue: formData.brand,
          onChanged: (value) {
            formData.brand = value.isEmpty ? null : value;
          },
        ),
        if (isCompact && index < _selectedImages.length - 1) ...[
          const SizedBox(height: 16),
          const Divider(),
        ],
      ],
    );
  }
}

// Helper class to store form data for each item
class ItemFormData {
  String? type;
  String? subType;
  String? brand;

  ItemFormData({
    this.type,
    this.subType,
    this.brand,
  });
}
