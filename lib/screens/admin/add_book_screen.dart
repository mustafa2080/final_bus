import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/book_model.dart';
import '../../services/book_service.dart';

/// شاشة إضافة / تعديل كتاب
/// لو تم تمرير [bookId] فالشاشة في وضع التعديل، غير كده وضع الإضافة
class AddBookScreen extends StatefulWidget {
  final String? bookId;

  const AddBookScreen({super.key, this.bookId});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final BookService _bookService = BookService();

  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverUrlController = TextEditingController();
  final _contentController = TextEditingController();
  final _pageCountController = TextEditingController();
  final _categoryController = TextEditingController();

  bool _isAvailable = true;
  bool _isLoading = false;
  bool _isFetchingBook = false;
  BookModel? _existingBook;

  bool get _isEditing => widget.bookId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadBook();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _coverUrlController.dispose();
    _contentController.dispose();
    _pageCountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadBook() async {
    setState(() => _isFetchingBook = true);
    try {
      final book = await _bookService.getBookById(widget.bookId!);
      if (book != null) {
        _existingBook = book;
        _titleController.text = book.title;
        _authorController.text = book.author;
        _descriptionController.text = book.description;
        _coverUrlController.text = book.coverUrl;
        _contentController.text = book.content;
        _pageCountController.text = book.pageCount.toString();
        _categoryController.text = book.category;
        _isAvailable = book.isAvailable;
      }
    } catch (e) {
      debugPrint('❌ Error loading book: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تحميل بيانات الكتاب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingBook = false);
      }
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final book = BookModel(
        id: _existingBook?.id ?? '',
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        description: _descriptionController.text.trim(),
        coverUrl: _coverUrlController.text.trim(),
        content: _contentController.text.trim(),
        publishedDate: _existingBook?.publishedDate ?? DateTime.now(),
        pageCount: int.tryParse(_pageCountController.text.trim()) ?? 0,
        category: _categoryController.text.trim(),
        rating: _existingBook?.rating ?? 0.0,
        reviewsCount: _existingBook?.reviewsCount ?? 0,
        isAvailable: _isAvailable,
      );

      if (_isEditing) {
        await _bookService.updateBook(book);
      } else {
        await _bookService.addBook(book);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'تم تحديث الكتاب بنجاح' : 'تم إضافة الكتاب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('❌ Error saving book: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في حفظ الكتاب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل كتاب' : 'إضافة كتاب جديد'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isFetchingBook
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width < 600
                      ? double.infinity
                      : 700,
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _titleController,
                          label: 'عنوان الكتاب',
                          icon: Icons.title,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'من فضلك أدخل عنوان الكتاب' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _authorController,
                          label: 'اسم المؤلف',
                          icon: Icons.person,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'من فضلك أدخل اسم المؤلف' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _categoryController,
                          label: 'التصنيف',
                          icon: Icons.category,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _coverUrlController,
                          label: 'رابط صورة الغلاف',
                          icon: Icons.image,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _pageCountController,
                          label: 'عدد الصفحات',
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'وصف الكتاب',
                          icon: Icons.description,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _contentController,
                          label: 'محتوى الكتاب',
                          icon: Icons.menu_book,
                          maxLines: 6,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('متاح للقراءة'),
                          value: _isAvailable,
                          activeThumbColor: const Color(0xFF1E88E5),
                          onChanged: (value) {
                            setState(() => _isAvailable = value);
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveBook,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة الكتاب'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => context.pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('إلغاء'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
