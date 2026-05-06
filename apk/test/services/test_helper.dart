import 'dart:convert';
import 'package:http/http.dart' as http;

/// Creates an HTTP response with UTF-8 encoded JSON body.
http.Response mockResponse(String jsonBody, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonBody),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Creates a MockClient that returns the given JSON body for any request.
http.Client mockClient(String jsonBody, {int statusCode = 200}) {
  return _SimpleMockClient((_) async => mockResponse(jsonBody, statusCode: statusCode));
}

/// Creates a MockClient with a handler that receives the request.
http.Client mockClientHandler(Future<http.Response> Function(http.BaseRequest) handler) {
  return _SimpleMockClient(handler);
}

class _SimpleMockClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest) _handler;
  _SimpleMockClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.contentLength,
      headers: response.headers,
      request: request,
    );
  }
}
