/// Configuration for external APIs
class ApiConfig {
  // ⚠️ SECURITY WARNING: API keys are sensitive!
  // DO NOT COMMIT THESE TO GITHUB! Use environment variables in production.

  // RapidAPI Configuration - Amazon
  static const String rapidApiHost = 'amazon-product-review.p.rapidapi.com';
  static const String rapidApiKey =
      '2a6e50141emsh071298458532d28p1b00b1jsn81604afa493e';

  // RapidAPI Configuration - Flipkart
  static const String flipkartApiHost = 'flipkart-api.p.rapidapi.com';
  static const String flipkartApiKey =
      '2a6e50141emsh071298458532d28p1b00b1jsn81604afa493e';

  // Base URLs
  static const String amazonApiUrl =
      'https://amazon-product-review.p.rapidapi.com/search';
  static const String flipkartApiUrl =
      'https://flipkart-api.p.rapidapi.com/search';

  // Headers for Amazon API requests
  static Map<String, String> get amazonHeaders {
    return {
      'Content-Type': 'application/json',
      'X-RapidAPI-Key': rapidApiKey,
      'X-RapidAPI-Host': rapidApiHost,
    };
  }

  // Headers for Flipkart API requests
  static Map<String, String> get flipkartHeaders {
    return {
      'Content-Type': 'application/json',
      'X-RapidAPI-Key': flipkartApiKey,
      'X-RapidAPI-Host': flipkartApiHost,
    };
  }

  // Fallback for backwards compatibility
  static Map<String, String> get rapidApiHeaders => amazonHeaders;

  // Request timeout (in seconds)
  static const int requestTimeout = 15;

  // Maximum results per search
  static const int maxResults = 10;
}
