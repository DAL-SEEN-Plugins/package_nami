class Constants {
  Constants._();
  static const int disconnected = 0;
  static const int connecting = 1;
  static const int connected = 2;
  static const int TCP_IP = 1;
  static const int BT = 2;

  static const int CHECK_STATUS_TIME_INTERVAL = 30;
  static const int PING_TIMEOUT = 2;
  static const int INVALID_LOG_LEVEL = 3;
  static const int DEFAULT_LOG_LEVEL = 0;
  static const int MINIMUM_CONNECTION_RETRY_COUNT = 1;
  static const int MINIMUM_DAYS_TO_RETAIN_LOG = 1;
  static const int MINIMUM_CONNECTION_TIMEOUT = 30;
  static const int CHECK_STATUS = 7;
  static const int TCP_UP = 1000;
  static const int TCP_DOWN = 1001;
  static const int TCP_IP_NOT_CONFIGURED = 1002;
  static const int TCP_PORT_NOT_CONFIGURED = 1003;
  static const int PAYMENT_APP_DOWN = 3000;

  static const int BT_UP = 2000;
  static const int BT_DOWN = 2001;
  static const int BT_SSID_NOT_CONFIGURED = 2002;

  static const int APPTOAPP = 3;
  static const int SERIAL = 3; // Note: Same value as APPTOAPP
  static const String TCP_PORT = "6000";
  static const int UDP_PORT = 8888;
  static const int UDP_SOCKET_TIMEOUT = 1000;
  static const String INET_ADDRESS = "255.255.255.255";
  static const int REGISTER = 3;
  static const String TCP_IP_STR = "TCPIP";
  static const String BT_STR = "BT";
  static const String ATA_STR = "App";
  static const String url = 'ws://127.0.0.1:8080';
  static const String localhost = 'localhost';

  static const String uuid = "8ce255c0-200a-11e0-ac64-0800200c9a66";
  static const String Deviceconnectedsuccss = " Device connected successfully";
  static const String Deviceconnectfailed = "Device connection failed";
  static const String TimeFormat = "yyyy-MM-dd HH:mm:ss";
  static const String kLogFileRegex = r'log_data_(\d{4}-\d{2}-\d{2})\.txt';

  // Connection error codes
  static const int SUCCESS = 0;
  static const int SENDING_FAILED = -1001;
  static const int RECEIVE_FAILED = -1002;
  static const String IO_EXCEPTION = "IOException";
  static const String EXTERNAL_STORAGE_ERR_MSG =
      "External storage not available";
  static const String bluetoothPermissionError =
      "Bluetooth permissions not granted";

  // Status messages
  static const String statusDisconnected = "Disconnected";
  static const String statusConnecting = "Connecting";
  static const String statusConnected = "Connected";
  static const String statusUnckown = "Unknown";

  // Event codes
  static const int payAppActive = 1000;
  static const int payAppInactive = 3000;

  static const String registerRequestSent = "Register request sent:";
}
