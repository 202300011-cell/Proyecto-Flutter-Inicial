import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/api_post.dart';

class ApiService {
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';

  static Future<List<ApiPost>> fetchPosts() async {
    final response = await http.get(Uri.parse('$baseUrl/posts'));
    if (response.statusCode != 200) {
      throw Exception('No se pudo cargar la API');
    }

    return await compute(parsePosts, response.body);
  }

  static ApiPost parsePost(Map<String, dynamic> json) {
    return ApiPost.fromJson(json);
  }

  static Future<ApiPost> createPost(ApiPost post) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(post.toJson()),
    );
    if (response.statusCode != 201) {
      throw Exception('No se pudo crear el post');
    }
    return ApiPost.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<ApiPost> updatePost(ApiPost post) async {
    final response = await http.put(
      Uri.parse('$baseUrl/posts/${post.id}'),
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(post.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('No se pudo actualizar el post');
    }
    return ApiPost.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static Future<bool> deletePost(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/posts/$id'));
    return response.statusCode == 200;
  }
}

List<ApiPost> parsePosts(String body) {
  final decoded = jsonDecode(body) as List<dynamic>;
  return decoded.map((item) => ApiPost.fromJson(item as Map<String, dynamic>)).toList();
}
