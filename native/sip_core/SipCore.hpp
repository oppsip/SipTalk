#pragma once

#include <functional>
#include <memory>
#include <string>

namespace siptalk {

enum class SipLogLevel {
    debug,
    info,
    warning,
    error,
};

struct SipAccountConfig {
    std::string id;
    std::string displayName;
    std::string domain;
    std::string username;
    std::string password;
    std::string authUsername;
    std::string proxy;
    std::string transport;
    int registrationExpiresSeconds = 300;
};

struct SipEvent {
    std::string type;
    std::string accountId;
    std::string callId;
    std::string payloadJson;
};

using SipEventHandler = std::function<void(const SipEvent&)>;

class SipCore {
public:
    SipCore();
    ~SipCore();

    SipCore(const SipCore&) = delete;
    SipCore& operator=(const SipCore&) = delete;

    void setEventHandler(SipEventHandler handler);

    void initialize();
    void shutdown();

    void createAccount(const SipAccountConfig& config);
    void registerAccount(const std::string& accountId);
    void unregisterAccount(const std::string& accountId);

    std::string makeCall(const std::string& accountId, const std::string& destination);
    void answerCall(const std::string& callId);
    void rejectCall(const std::string& callId);
    void hangupCall(const std::string& callId);
    void holdCall(const std::string& callId);
    void resumeCall(const std::string& callId);
    void sendDtmf(const std::string& callId, const std::string& digits);
    void setMuted(const std::string& callId, bool muted);
    void setAudioRoute(const std::string& route);

private:
    class Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace siptalk
