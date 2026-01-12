import 'integration_tests/server_connectivity_test.dart'
    as server_connectivity_test;
import 'integration_tests/message_flow_test.dart' as message_flow_test;
import 'integration_tests/streaming_response_test.dart'
    as streaming_response_test;
import 'widget_tests/connection_indicator_test.dart'
    as connection_indicator_test;

void main() {
  // Run all tests
  server_connectivity_test.main();
  message_flow_test.main();
  streaming_response_test.main();
  connection_indicator_test.main();
}
