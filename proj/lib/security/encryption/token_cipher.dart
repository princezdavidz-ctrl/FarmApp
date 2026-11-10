import 'dart:convert';

class TokenCipher {
	String encode(String token) => base64UrlEncode(utf8.encode(token));
	String decode(String value) => utf8.decode(base64Url.decode(value));
}
