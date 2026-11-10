import 'dart:convert';
import 'package:crypto/crypto.dart';

class HashService {
	String sha256Hash(String value) => sha256.convert(utf8.encode(value)).toString();
}
