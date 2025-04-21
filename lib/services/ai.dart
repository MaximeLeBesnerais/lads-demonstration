import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// A service class to interact with the Google Gemini API using structured output.
/// API key must be set using [setApiKey] before calling [generateStructuredContent].
class GeminiService {
  String? _apiKey;
  // Ensure the model ID is exactly as requested
  final String modelId = "gemini-2.0-flash";
  final String _baseUrl = "https://generativelanguage.googleapis.com/v1beta/models";
  final String _endpoint = "generateContent";

  // Define the structured response schema expected from the API
  final Map<String, dynamic> _responseSchema = {
    "type": "object",
    "properties": {
      "instructions": {
        "type": "array",
        "items": {"type": "string"}
      },
      "message": {"type": "string"},
      "answer_type": {
        "type": "string",
        "enum": ["message", "instructions"]
      }
    },
    "required": ["answer_type"]
  };

  GeminiService(); // Default constructor is fine

  void setApiKey(String key) {
    _apiKey = key;
    print('Gemini API Key has been set.');
  }

  bool isApiKeySet() {
    return _apiKey != null && _apiKey!.isNotEmpty;
  }

  /// Sends the user prompt and system instruction to the Gemini API,
  /// requesting structured JSON output.
  ///
  /// Returns a Map<String, dynamic> representing the parsed JSON response.
  /// Throws an Exception if the API key is not set, the request fails,
  /// or the response format is unexpected.
  Future<Map<String, dynamic>> generateStructuredContent(
      String userPrompt, String systemInstructionText) async {
    if (!isApiKeySet()) {
      throw Exception('API Key not set. Please call setApiKey first.');
    }

    final url = Uri.parse("$_baseUrl/$modelId:$_endpoint?key=${_apiKey!}");

    final headers = {
      'Content-Type': 'application/json',
    };

    // Construct the request body with systemInstruction and generationConfig
    final body = jsonEncode({
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": userPrompt}
          ]
        }
      ],
      "systemInstruction": {
        "parts": [
          {"text": systemInstructionText}
        ]
      },
      "generationConfig": {
        "responseMimeType": "application/json",
        "responseSchema": _responseSchema,
      },
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);

        // Extract the actual content part which should be JSON text
        final content = decodedResponse?['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (content is String) {
          // The API wraps the JSON in a text field, so we need to decode it again
          try {
            final Map<String, dynamic> structuredData = jsonDecode(content);
             // Basic validation based on schema
            if (structuredData.containsKey('answer_type') &&
                (structuredData['answer_type'] == 'instructions' || structuredData['answer_type'] == 'message')) {
                 return structuredData;
            } else {
                 print('Gemini response missing required fields or invalid answer_type: $content');
                 throw Exception('Invalid structured data format from Gemini.');
            }

          } catch (e) {
            print('Error decoding the structured JSON content from Gemini: $e');
            print('Raw content string: $content');
            throw Exception('Could not decode structured JSON from Gemini response.');
          }
        } else {
           print('Unexpected Gemini response format - content part is not a string: ${response.body}');
           throw Exception('Could not extract text content part from Gemini response.');
        }
      } else {
        // Attempt to parse error details if available
        String errorMessage = 'Gemini API request failed with status ${response.statusCode}';
        try {
            final errorBody = jsonDecode(response.body);
            if (errorBody['error'] != null && errorBody['error']['message'] != null) {
                errorMessage += ': ${errorBody['error']['message']}';
            } else {
                 errorMessage += '\nResponse Body: ${response.body}';
            }
        } catch (_) {
             errorMessage += '\nResponse Body: ${response.body}'; // Fallback if error parsing fails
        }
        print(errorMessage);
        throw Exception(errorMessage);
      }
    } on TimeoutException catch (e) {
      print('Gemini API request timed out: $e');
      throw Exception('Gemini API request timed out.');
    } catch (e) {
      // Catch specific exceptions if needed, otherwise rethrow or wrap
       if (e is Exception) {
           rethrow; // Rethrow known exceptions
       } else {
           print('Unexpected error processing Gemini API call: $e');
           throw Exception('Failed to process Gemini API call.');
       }
    }
  }
}
