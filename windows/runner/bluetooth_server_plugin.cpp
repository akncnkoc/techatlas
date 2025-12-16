#include "bluetooth_server_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <sstream>
#include <iomanip>

namespace bluetooth_server {

// static
void BluetoothServerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<BluetoothServerPlugin>(registrar);
  registrar->AddPlugin(std::move(plugin));
}

BluetoothServerPlugin::BluetoothServerPlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar),
      server_running_(false),
      should_stop_(false),
      server_socket_(INVALID_SOCKET) {

  // Initialize Winsock
  WSADATA wsa_data;
  WSAStartup(MAKEWORD(2, 2), &wsa_data);

  // Create method channel
  method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.techatlas.bluetooth_server",
      &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        this->HandleMethodCall(call, std::move(result));
      });

  // Create event channel
  event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.techatlas.bluetooth_server/events",
      &flutter::StandardMethodCodec::GetInstance());

  auto handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        event_sink_ = std::move(events);
        return nullptr;
      },
      [this](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        event_sink_ = nullptr;
        return nullptr;
      });

  event_channel_->SetStreamHandler(std::move(handler));
}

BluetoothServerPlugin::~BluetoothServerPlugin() {
  StopServer();
  WSACleanup();
}

void BluetoothServerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto& method_name = method_call.method_name();

  if (method_name == "startServer") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENT", "Arguments must be a map");
      return;
    }

    std::string service_name = "Drawing Pen Remote";
    std::string service_uuid = "00001101-0000-1000-8000-00805F9B34FB";

    auto name_it = arguments->find(flutter::EncodableValue("serviceName"));
    if (name_it != arguments->end()) {
      service_name = std::get<std::string>(name_it->second);
    }

    auto uuid_it = arguments->find(flutter::EncodableValue("serviceUuid"));
    if (uuid_it != arguments->end()) {
      service_uuid = std::get<std::string>(uuid_it->second);
    }

    bool success = StartServer(service_name, service_uuid);
    result->Success(flutter::EncodableValue(success));
  }
  else if (method_name == "stopServer") {
    StopServer();
    result->Success(flutter::EncodableValue(true));
  }
  else if (method_name == "sendMessage") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (!arguments) {
      result->Error("INVALID_ARGUMENT", "Arguments must be a map");
      return;
    }

    auto msg_it = arguments->find(flutter::EncodableValue("message"));
    if (msg_it == arguments->end()) {
      result->Error("INVALID_ARGUMENT", "Message is required");
      return;
    }

    std::string message = std::get<std::string>(msg_it->second);
    bool success = SendMessage(message);
    result->Success(flutter::EncodableValue(success));
  }
  else if (method_name == "disconnectClients") {
    DisconnectClients();
    result->Success(flutter::EncodableValue(true));
  }
  else if (method_name == "isBluetoothAvailable") {
    bool available = IsBluetoothAvailable();
    result->Success(flutter::EncodableValue(available));
  }
  else if (method_name == "isBluetoothEnabled") {
    bool enabled = IsBluetoothEnabled();
    result->Success(flutter::EncodableValue(enabled));
  }
  else {
    result->NotImplemented();
  }
}

bool BluetoothServerPlugin::StartServer(const std::string& service_name,
                                         const std::string& service_uuid) {
  if (server_running_) {
    SendEvent("error", "", "", "", "Server already running");
    return false;
  }

  service_name_ = service_name;
  service_uuid_ = service_uuid;

  // Create Bluetooth RFCOMM socket
  server_socket_ = socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
  if (server_socket_ == INVALID_SOCKET) {
    SendEvent("error", "", "", "", "Failed to create socket");
    return false;
  }

  // Bind to any available Bluetooth adapter
  SOCKADDR_BTH bind_addr = {};
  bind_addr.addressFamily = AF_BTH;
  bind_addr.btAddr = 0; // BDADDR_ANY
  bind_addr.port = BT_PORT_ANY;

  if (bind(server_socket_, (SOCKADDR*)&bind_addr, sizeof(bind_addr)) == SOCKET_ERROR) {
    SendEvent("error", "", "", "", "Failed to bind socket");
    closesocket(server_socket_);
    server_socket_ = INVALID_SOCKET;
    return false;
  }

  // Get the assigned port
  int addr_len = sizeof(bind_addr);
  if (getsockname(server_socket_, (SOCKADDR*)&bind_addr, &addr_len) == SOCKET_ERROR) {
    SendEvent("error", "", "", "", "Failed to get socket name");
    closesocket(server_socket_);
    server_socket_ = INVALID_SOCKET;
    return false;
  }

  // Listen for connections
  if (listen(server_socket_, SOMAXCONN) == SOCKET_ERROR) {
    SendEvent("error", "", "", "", "Failed to listen on socket");
    closesocket(server_socket_);
    server_socket_ = INVALID_SOCKET;
    return false;
  }

  // Register SDP service
  WSAQUERYSET service = {};
  GUID service_guid;
  UuidFromStringA((RPC_CSTR)service_uuid_.c_str(), &service_guid);

  service.dwSize = sizeof(service);
  service.lpServiceClassId = &service_guid;

  // Convert service name to wide string for Windows API
  int len = MultiByteToWideChar(CP_UTF8, 0, service_name_.c_str(), -1, nullptr, 0);
  std::vector<wchar_t> wide_name(len);
  MultiByteToWideChar(CP_UTF8, 0, service_name_.c_str(), -1, wide_name.data(), len);

  service.lpszServiceInstanceName = wide_name.data();
  service.dwNameSpace = NS_BTH;

  SOCKADDR_BTH service_addr = {};
  service_addr.addressFamily = AF_BTH;
  service_addr.btAddr = 0;
  service_addr.port = bind_addr.port;
  service_addr.serviceClassId = service_guid;

  CSADDR_INFO csai = {};
  csai.LocalAddr.lpSockaddr = (SOCKADDR*)&service_addr;
  csai.LocalAddr.iSockaddrLength = sizeof(service_addr);
  csai.iSocketType = SOCK_STREAM;
  csai.iProtocol = BTHPROTO_RFCOMM;

  service.lpcsaBuffer = &csai;
  service.dwNumberOfCsAddrs = 1;

  if (WSASetService(&service, RNRSERVICE_REGISTER, 0) == SOCKET_ERROR) {
    // Non-fatal error, continue anyway
  }

  // Start server thread
  should_stop_ = false;
  server_running_ = true;
  server_thread_ = std::thread(&BluetoothServerPlugin::ServerThread, this);

  return true;
}

void BluetoothServerPlugin::StopServer() {
  if (!server_running_) {
    return;
  }

  should_stop_ = true;
  server_running_ = false;

  // Close all client sockets
  DisconnectClients();

  // Close server socket
  if (server_socket_ != INVALID_SOCKET) {
    closesocket(server_socket_);
    server_socket_ = INVALID_SOCKET;
  }

  // Wait for server thread to finish
  if (server_thread_.joinable()) {
    server_thread_.join();
  }
}

void BluetoothServerPlugin::ServerThread() {
  while (!should_stop_ && server_socket_ != INVALID_SOCKET) {
    SOCKADDR_BTH client_addr = {};
    int addr_len = sizeof(client_addr);

    // Accept client connection (with timeout)
    fd_set read_fds;
    FD_ZERO(&read_fds);
    FD_SET(server_socket_, &read_fds);

    timeval timeout;
    timeout.tv_sec = 1;
    timeout.tv_usec = 0;

    int select_result = select(0, &read_fds, nullptr, nullptr, &timeout);
    if (select_result == SOCKET_ERROR || !FD_ISSET(server_socket_, &read_fds)) {
      continue;
    }

    SOCKET client_socket = accept(server_socket_, (SOCKADDR*)&client_addr, &addr_len);
    if (client_socket == INVALID_SOCKET) {
      continue;
    }

    // Convert client address to string
    std::stringstream ss;
    ss << std::hex << std::setfill('0');
    ULONGLONG addr = client_addr.btAddr;
    for (int i = 5; i >= 0; i--) {
      ss << std::setw(2) << ((addr >> (i * 8)) & 0xFF);
      if (i > 0) ss << ":";
    }
    std::string client_address = ss.str();

    // Add to client list
    {
      std::lock_guard<std::mutex> lock(clients_mutex_);
      client_sockets_.push_back(client_socket);
    }

    // Send connected event
    SendEvent("clientConnected", client_address, "Unknown");

    // Start client handler thread
    std::thread(&BluetoothServerPlugin::ClientHandlerThread, this, client_socket, client_address).detach();
  }
}

void BluetoothServerPlugin::ClientHandlerThread(SOCKET client_socket, std::string client_address) {
  char buffer[4096];

  while (!should_stop_) {
    int bytes_received = recv(client_socket, buffer, sizeof(buffer) - 1, 0);

    if (bytes_received > 0) {
      buffer[bytes_received] = '\0';
      std::string message(buffer);

      // Send message received event
      SendEvent("messageReceived", client_address, "", message);
    }
    else if (bytes_received == 0 || bytes_received == SOCKET_ERROR) {
      // Client disconnected
      break;
    }
  }

  // Remove from client list
  {
    std::lock_guard<std::mutex> lock(clients_mutex_);
    client_sockets_.erase(
        std::remove(client_sockets_.begin(), client_sockets_.end(), client_socket),
        client_sockets_.end());
  }

  closesocket(client_socket);
  SendEvent("clientDisconnected", client_address);
}

bool BluetoothServerPlugin::SendMessage(const std::string& message) {
  std::lock_guard<std::mutex> lock(clients_mutex_);

  if (client_sockets_.empty()) {
    return false;
  }

  bool all_success = true;
  for (SOCKET client_socket : client_sockets_) {
    int result = send(client_socket, message.c_str(), message.length(), 0);
    if (result == SOCKET_ERROR) {
      all_success = false;
    }
  }

  return all_success;
}

void BluetoothServerPlugin::DisconnectClients() {
  std::lock_guard<std::mutex> lock(clients_mutex_);

  for (SOCKET client_socket : client_sockets_) {
    closesocket(client_socket);
  }
  client_sockets_.clear();
}

bool BluetoothServerPlugin::IsBluetoothAvailable() {
  HANDLE radio_handle = nullptr;
  BLUETOOTH_FIND_RADIO_PARAMS params = {};
  params.dwSize = sizeof(params);

  HBLUETOOTH_RADIO_FIND find_handle = BluetoothFindFirstRadio(&params, &radio_handle);
  if (find_handle != nullptr) {
    CloseHandle(radio_handle);
    BluetoothFindRadioClose(find_handle);
    return true;
  }

  return false;
}

bool BluetoothServerPlugin::IsBluetoothEnabled() {
  HANDLE radio_handle = nullptr;
  BLUETOOTH_FIND_RADIO_PARAMS params = {};
  params.dwSize = sizeof(params);

  HBLUETOOTH_RADIO_FIND find_handle = BluetoothFindFirstRadio(&params, &radio_handle);
  if (find_handle != nullptr) {
    BLUETOOTH_RADIO_INFO radio_info = {};
    radio_info.dwSize = sizeof(radio_info);

    DWORD result = BluetoothGetRadioInfo(radio_handle, &radio_info);

    CloseHandle(radio_handle);
    BluetoothFindRadioClose(find_handle);

    return result == ERROR_SUCCESS;
  }

  return false;
}

void BluetoothServerPlugin::SendEvent(const std::string& type,
                                       const std::string& client_address,
                                       const std::string& client_name,
                                       const std::string& message,
                                       const std::string& error) {
  if (!event_sink_) {
    return;
  }

  flutter::EncodableMap event_map;
  event_map[flutter::EncodableValue("type")] = flutter::EncodableValue(type);

  if (!client_address.empty()) {
    event_map[flutter::EncodableValue("clientAddress")] = flutter::EncodableValue(client_address);
  }
  if (!client_name.empty()) {
    event_map[flutter::EncodableValue("clientName")] = flutter::EncodableValue(client_name);
  }
  if (!message.empty()) {
    event_map[flutter::EncodableValue("message")] = flutter::EncodableValue(message);
  }
  if (!error.empty()) {
    event_map[flutter::EncodableValue("error")] = flutter::EncodableValue(error);
  }

  event_sink_->Success(flutter::EncodableValue(event_map));
}

}  // namespace bluetooth_server
