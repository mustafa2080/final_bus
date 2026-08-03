
import 'package:flutter/material.dart';

class BookModel {
  final String id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final String content;
  final DateTime publishedDate;
  final int pageCount;
  final String category;
  final double rating;
  final int reviewsCount;
  final bool isAvailable;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    required this.content,
    required this.publishedDate,
    required this.pageCount,
    required this.category,
    required this.rating,
    required this.reviewsCount,
    required this.isAvailable,
  });

  // دالة لإنشاء نسخة من الكائن مع تعديل بعض الخصائص
  BookModel copyWith({
    String? id,
    String? title,
    String? author,
    String? description,
    String? coverUrl,
    String? content,
    DateTime? publishedDate,
    int? pageCount,
    String? category,
    double? rating,
    int? reviewsCount,
    bool? isAvailable,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      content: content ?? this.content,
      publishedDate: publishedDate ?? this.publishedDate,
      pageCount: pageCount ?? this.pageCount,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  // دالة لتحويل الكائن إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'coverUrl': coverUrl,
      'content': content,
      'publishedDate': publishedDate.toIso8601String(),
      'pageCount': pageCount,
      'category': category,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'isAvailable': isAvailable,
    };
  }

  // دالة لإنشاء كائن من JSON
  static BookModel fromJson(Map<String, dynamic> json) {
    return BookModel(
      id: json['id'],
      title: json['title'],
      author: json['author'],
      description: json['description'],
      coverUrl: json['coverUrl'],
      content: json['content'],
      publishedDate: DateTime.parse(json['publishedDate']),
      pageCount: json['pageCount'],
      category: json['category'],
      rating: json['rating'],
      reviewsCount: json['reviewsCount'],
      isAvailable: json['isAvailable'],
    );
  }
}
