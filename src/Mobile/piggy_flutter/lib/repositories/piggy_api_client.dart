import 'dart:convert';

import 'package:piggy_flutter/models/api_response.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:piggy_flutter/models/models.dart';
import 'package:piggy_flutter/utils/uidata.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PiggyApiClient {
  static const baseUrl = 'https://piggyvault.in';
  // static const baseUrl = 'http://10.0.2.2:21021';
  // static const baseUrl = 'http://localhost:21021';
  final http.Client httpClient;

  PiggyApiClient({@required this.httpClient}) : assert(httpClient != null);

  Future<IsTenantAvailableResult> isTenantAvailable(String tenancyName) async {
    final tenantUrl = '$baseUrl/api/services/app/Account/IsTenantAvailable';
    final response =
        await this.postAsync(tenantUrl, {"tenancyName": tenancyName});

    if (!response.success) {
      throw Exception('invalid credentials');
    }

    return IsTenantAvailableResult.fromJson(response.result);
  }

  Future<AuthenticateResult> authenticate(
      {@required String usernameOrEmailAddress,
      @required String password}) async {
    final loginUrl = '$baseUrl/api/TokenAuth/Authenticate';
    final loginResult = await this.postAsync(loginUrl, {
      "usernameOrEmailAddress": usernameOrEmailAddress,
      "password": password,
      "rememberClient": true
    });

    if (!loginResult.success) {
      throw Exception(loginResult.error);
    }
    return AuthenticateResult.fromJson(loginResult.result);
  }

  Future<User> getCurrentLoginInformations() async {
    final userUrl =
        '$baseUrl/api/services/app/session/GetCurrentLoginInformations';
    final response = await this.getAsync(userUrl);

    if (response.success && response.result['user'] != null) {
      return User.fromJson(response.result['user']);
    }

    return null;
  }

// utils
  Future<AjaxResponse<T>> getAsync<T>(String resourcePath) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(UIData.authToken);
    var tenantId = prefs.getInt(UIData.tenantId);
    var response = await this.httpClient.get(resourcePath, headers: {
      'Content-type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'Piggy-TenantId': tenantId.toString()
    });
    return processResponse<T>(response);
  }

  Future<AjaxResponse<T>> postAsync<T>(
      String resourcePath, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(UIData.authToken);
    var tenantId = prefs.getInt(UIData.tenantId);

    var content = json.encoder.convert(data);
    Map<String, String> headers;

    if (token == null) {
      headers = {
        'Content-type': 'application/json',
        'Accept': 'application/json',
        'Piggy-TenantId': tenantId.toString()
      };
    } else {
      headers = {
        'Content-type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Piggy-TenantId': tenantId.toString()
      };
    }

    // print(content);
    var response =
        await http.post(resourcePath, body: content, headers: headers);
    return processResponse<T>(response);
  }

  AjaxResponse<T> processResponse<T>(http.Response response) {
    try {
      // if (!((response.statusCode < 200) ||
      //     (response.statusCode >= 300) ||
      //     (response.body == null))) {
      var jsonResult = response.body;
      dynamic parsedJson = jsonDecode(jsonResult);

      // print(jsonResult);

      var output = AjaxResponse<T>(
        result: parsedJson["result"],
        success: parsedJson["success"],
        unAuthorizedRequest: parsedJson['unAuthorizedRequest'],
      );

      if (!output.success) {
        output.error = parsedJson["error"]["message"];
      }
      return output;
    } catch (e) {
      return AjaxResponse<T>(
          result: null,
          success: false,
          unAuthorizedRequest: false,
          error: 'Something went wrong. Please try again');
    }
  }
}
