import 'dart:convert';

class AesEncryption {
	const AesEncryption();
	String encode(String value) => base64UrlEncode(utf8.encode(value));
	String decode(String value) => utf8.decode(base64Url.decode(value));
}
