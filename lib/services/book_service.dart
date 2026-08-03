import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_model.dart';

/// خدمة إدارة الكتب (مكتبة القراءة)
class BookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'books';

  CollectionReference<Map<String, dynamic>> get _booksCollection =>
      _firestore.collection(_collectionName);

  /// تحويل مستند Firestore إلى BookModel بأمان (يدعم غياب بعض الحقول)
  BookModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime publishedDate;
    final rawDate = data['publishedDate'];
    if (rawDate is Timestamp) {
      publishedDate = rawDate.toDate();
    } else if (rawDate is String) {
      publishedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      publishedDate = DateTime.now();
    }

    return BookModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      author: data['author'] as String? ?? '',
      description: data['description'] as String? ?? '',
      coverUrl: data['coverUrl'] as String? ?? '',
      content: data['content'] as String? ?? '',
      publishedDate: publishedDate,
      pageCount: (data['pageCount'] as num?)?.toInt() ?? 0,
      category: data['category'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: (data['reviewsCount'] as num?)?.toInt() ?? 0,
      isAvailable: data['isAvailable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _toMap(BookModel book) {
    return {
      'title': book.title,
      'author': book.author,
      'description': book.description,
      'coverUrl': book.coverUrl,
      'content': book.content,
      'publishedDate': Timestamp.fromDate(book.publishedDate),
      'pageCount': book.pageCount,
      'category': book.category,
      'rating': book.rating,
      'reviewsCount': book.reviewsCount,
      'isAvailable': book.isAvailable,
    };
  }

  /// جلب كل الكتب
  Future<List<BookModel>> getAllBooks() async {
    try {
      final snapshot = await _booksCollection.orderBy('title').get();
      return snapshot.docs.map(_fromDoc).toList();
    } catch (e) {
      final snapshot = await _booksCollection.get();
      return snapshot.docs.map(_fromDoc).toList();
    }
  }

  /// جلب كتاب واحد عن طريق الـ id
  Future<BookModel?> getBookById(String bookId) async {
    final doc = await _booksCollection.doc(bookId).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  /// البحث عن كتب بالعنوان أو المؤلف
  Future<List<BookModel>> searchBooks(String query) async {
    if (query.trim().isEmpty) {
      return getAllBooks();
    }

    final books = await getAllBooks();
    final lowerQuery = query.toLowerCase();

    return books.where((book) {
      return book.title.toLowerCase().contains(lowerQuery) ||
          book.author.toLowerCase().contains(lowerQuery) ||
          book.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// إضافة كتاب جديد
  Future<String> addBook(BookModel book) async {
    final docRef = await _booksCollection.add(_toMap(book));
    return docRef.id;
  }

  /// تعديل كتاب موجود
  Future<void> updateBook(BookModel book) async {
    await _booksCollection.doc(book.id).update(_toMap(book));
  }

  /// حذف كتاب
  Future<void> deleteBook(String bookId) async {
    await _booksCollection.doc(bookId).delete();
  }
}
