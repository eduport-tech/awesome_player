import 'dart:async';
import 'dart:convert';
import 'dart:io';

///Fake [HttpClient] which serves canned responses (e.g. HLS playlists) after a
///delay, so tests can interact with the player while a request is in flight.
///Urls without a canned response get an empty body, like a failed request.
class MockHttpClient implements HttpClient {
  ///Response body for each url.
  final Map<String, String> responses = {};

  ///Delay for each url. [defaultDelay] is used when url has no entry.
  final Map<String, Duration> delays = {};

  ///Urls requested so far, in request order.
  final List<String> requestedUrls = [];

  Duration defaultDelay = const Duration(milliseconds: 50);

  @override
  Duration? connectionTimeout;

  void reset() {
    responses.clear();
    delays.clear();
    requestedUrls.clear();
    defaultDelay = const Duration(milliseconds: 50);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final String key = url.toString();
    requestedUrls.add(key);
    return _MockHttpClientRequest(
        responses[key] ?? "", delays[key] ?? defaultDelay);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  _MockHttpClientRequest(this._body, this._delay);

  final String _body;
  final Duration _delay;

  @override
  Future<HttpClientResponse> close() async {
    await Future<void>.delayed(_delay);
    return _MockHttpClientResponse(utf8.encode(_body));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _MockHttpClientResponse(this._bytes);

  final List<int> _bytes;

  @override
  int get statusCode => 200;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
