#include "SipCore.hpp"

#include "SipCommandQueue.hpp"

#include <atomic>
#include <mutex>
#include <stdexcept>
#include <sstream>
#include <unordered_map>
#include <utility>

#if defined(SIPTALK_HAS_PJSIP)
#include <pjsua2.hpp>
#endif

namespace siptalk {

namespace {

std::string json_escape(const std::string& value)
{
    std::ostringstream escaped;
    for (const char ch : value) {
        switch (ch) {
        case '\\':
            escaped << "\\\\";
            break;
        case '"':
            escaped << "\\\"";
            break;
        case '\n':
            escaped << "\\n";
            break;
        case '\r':
            escaped << "\\r";
            break;
        case '\t':
            escaped << "\\t";
            break;
        default:
            escaped << ch;
            break;
        }
    }
    return escaped.str();
}

std::string json_registration_payload(
    const std::string& state,
    const std::string& reason,
    int statusCode,
    unsigned expiration)
{
    std::ostringstream payload;
    payload << "{\"state\":\"" << state << "\"";
    if (!reason.empty()) {
        payload << ",\"reason\":\"" << json_escape(reason) << "\"";
    }
    if (statusCode > 0) {
        payload << ",\"statusCode\":" << statusCode;
    }
    if (expiration > 0) {
        payload << ",\"expiration\":" << expiration;
    }
    payload << "}";
    return payload.str();
}

std::string sip_uri_for_user(const SipAccountConfig& config)
{
    return "sip:" + config.username + "@" + config.domain;
}

std::string registrar_uri_for(const SipAccountConfig& config)
{
    if (config.domain.rfind("sip:", 0) == 0 || config.domain.rfind("sips:", 0) == 0) {
        return config.domain;
    }
    return "sip:" + config.domain;
}

std::string destination_uri_for(const SipAccountConfig& config, const std::string& destination)
{
    if (destination.rfind("sip:", 0) == 0 || destination.rfind("sips:", 0) == 0) {
        return destination;
    }
    return "sip:" + destination + "@" + config.domain;
}

std::string json_call_payload(
    const std::string& state,
    const std::string& remoteUri,
    const std::string& reason,
    int statusCode)
{
    std::ostringstream payload;
    payload << "{\"state\":\"" << state << "\"";
    if (!remoteUri.empty()) {
        payload << ",\"remoteUri\":\"" << json_escape(remoteUri) << "\"";
    }
    if (!reason.empty()) {
        payload << ",\"reason\":\"" << json_escape(reason) << "\"";
    }
    if (statusCode > 0) {
        payload << ",\"statusCode\":" << statusCode;
    }
    payload << "}";
    return payload.str();
}

#if defined(SIPTALK_HAS_PJSIP)
std::string call_state_for(pjsip_inv_state state, pjsip_status_code lastStatusCode)
{
    switch (state) {
    case PJSIP_INV_STATE_NULL:
        return "Calling";
    case PJSIP_INV_STATE_CALLING:
        return "Calling";
    case PJSIP_INV_STATE_INCOMING:
        return "Ringing";
    case PJSIP_INV_STATE_EARLY:
    case PJSIP_INV_STATE_CONNECTING:
        return "Connecting";
    case PJSIP_INV_STATE_CONFIRMED:
        return "InCall";
    case PJSIP_INV_STATE_DISCONNECTED:
        return lastStatusCode >= 300 ? "Failed" : "Ended";
    default:
        return "Failed";
    }
}

class ManagedCall : public pj::Call {
public:
    ManagedCall(
        pj::Account& account,
        std::string accountId,
        std::string appCallId,
        SipEventHandler eventHandler)
        : pj::Call(account)
        , accountId_(std::move(accountId))
        , appCallId_(std::move(appCallId))
        , eventHandler_(std::move(eventHandler))
    {
    }

    void onCallState(pj::OnCallStateParam& prm) override
    {
        PJ_UNUSED_ARG(prm);

        try {
            const pj::CallInfo info = getInfo();
            const auto state = call_state_for(info.state, info.lastStatusCode);
            if (eventHandler_) {
                eventHandler_({
                    "CallStateChanged",
                    accountId_,
                    appCallId_,
                    json_call_payload(state, info.remoteUri, info.lastReason, info.lastStatusCode),
                });
            }
        } catch (const pj::Error& error) {
            if (eventHandler_) {
                eventHandler_({
                    "CallStateChanged",
                    accountId_,
                    appCallId_,
                    json_call_payload("Failed", "", error.info(), 0),
                });
            }
        }
    }

private:
    std::string accountId_;
    std::string appCallId_;
    SipEventHandler eventHandler_;
};

class ManagedAccount : public pj::Account {
public:
    ManagedAccount(std::string accountId, SipEventHandler eventHandler)
        : accountId_(std::move(accountId))
        , eventHandler_(std::move(eventHandler))
    {
    }

    void onRegState(pj::OnRegStateParam& prm) override
    {
        std::string state = "Registering";
        if (prm.code >= 200 && prm.code < 300 && prm.expiration > 0) {
            state = "Registered";
        } else if (prm.expiration == 0 && prm.code >= 200 && prm.code < 300) {
            state = "Offline";
        } else if (prm.status != PJ_SUCCESS || prm.code >= 300) {
            state = "RegistrationFailed";
        }

        if (eventHandler_) {
            eventHandler_({
                "AccountRegistrationChanged",
                accountId_,
                "",
                json_registration_payload(state, prm.reason, prm.code, prm.expiration),
            });
        }
    }

private:
    std::string accountId_;
    SipEventHandler eventHandler_;
};
#endif

} // namespace

class SipCore::Impl {
public:
    void emit(SipEvent event)
    {
        SipEventHandler copiedHandler;
        {
            std::lock_guard<std::mutex> lock(mutex);
            copiedHandler = handler;
        }

        if (copiedHandler) {
            copiedHandler(event);
        }
    }

    std::mutex mutex;
    SipEventHandler handler;
    std::unordered_map<std::string, SipAccountConfig> accounts;
    SipCommandQueue commandQueue;
    std::atomic<unsigned long long> nextCallId {1};
    bool initialized = false;

#if defined(SIPTALK_HAS_PJSIP)
    std::unique_ptr<pj::Endpoint> endpoint;
    std::unordered_map<std::string, std::unique_ptr<ManagedAccount>> pjsipAccounts;
    std::unordered_map<std::string, std::unique_ptr<ManagedCall>> pjsipCalls;
#endif
};

SipCore::SipCore()
    : impl_(std::make_unique<Impl>())
{
}

SipCore::~SipCore() = default;

void SipCore::setEventHandler(SipEventHandler handler)
{
    std::lock_guard<std::mutex> lock(impl_->mutex);
    impl_->handler = std::move(handler);
}

void SipCore::initialize()
{
    impl_->commandQueue.start();

    impl_->commandQueue.post([this] {
#if defined(SIPTALK_HAS_PJSIP)
        try {
            if (!impl_->endpoint) {
                impl_->endpoint = std::make_unique<pj::Endpoint>();
                impl_->endpoint->libCreate();

                pj::EpConfig epConfig;
                epConfig.uaConfig.threadCnt = 1;
                epConfig.uaConfig.mainThreadOnly = false;
                epConfig.logConfig.level = 4;
                epConfig.logConfig.consoleLevel = 4;
                impl_->endpoint->libInit(epConfig);

                pj::TransportConfig udpConfig;
                udpConfig.port = 0;
                impl_->endpoint->transportCreate(PJSIP_TRANSPORT_UDP, udpConfig);
                impl_->endpoint->libStart();
            }
        } catch (const pj::Error& error) {
            impl_->emit({"CoreFailed", "", "", "{\"message\":\"" + json_escape(error.info()) + "\"}"});
            if (impl_->endpoint) {
                try {
                    impl_->endpoint->libDestroy();
                } catch (...) {
                }
                impl_->endpoint.reset();
            }
            return;
        } catch (const std::exception& error) {
            impl_->emit({"CoreFailed", "", "", "{\"message\":\"" + json_escape(error.what()) + "\"}"});
            impl_->endpoint.reset();
            return;
        }
#endif

        {
            std::lock_guard<std::mutex> lock(impl_->mutex);
            impl_->initialized = true;
        }

        impl_->emit({"CoreReady", "", "", "{}"});
    });
}

void SipCore::shutdown()
{
    impl_->commandQueue.post([this] {
#if defined(SIPTALK_HAS_PJSIP)
        impl_->pjsipCalls.clear();
        impl_->pjsipAccounts.clear();
        if (impl_->endpoint) {
            try {
                impl_->endpoint->libDestroy();
            } catch (...) {
            }
            impl_->endpoint.reset();
        }
#endif

        {
            std::lock_guard<std::mutex> lock(impl_->mutex);
            impl_->accounts.clear();
            impl_->initialized = false;
        }

        impl_->emit({"CoreShutdown", "", "", "{}"});
    });
    impl_->commandQueue.drainAndStop();
}

void SipCore::createAccount(const SipAccountConfig& config)
{
    impl_->commandQueue.post([this, config] {
        {
            std::lock_guard<std::mutex> lock(impl_->mutex);
            impl_->accounts[config.id] = config;
        }
        impl_->emit({"AccountRegistrationChanged", config.id, "", "{\"state\":\"Configured\"}"});
    });
}

void SipCore::registerAccount(const std::string& accountId)
{
    impl_->commandQueue.post([this, accountId] {
        SipAccountConfig config;
        bool hasConfig = false;
        {
            std::lock_guard<std::mutex> lock(impl_->mutex);
            auto found = impl_->accounts.find(accountId);
            if (found != impl_->accounts.end()) {
                config = found->second;
                hasConfig = true;
            }
        }
        if (!hasConfig) {
            impl_->emit({
                "AccountRegistrationChanged",
                accountId,
                "",
                json_registration_payload("RegistrationFailed", "Account is not configured", 0, 0),
            });
            return;
        }

        impl_->emit({"AccountRegistrationChanged", accountId, "", "{\"state\":\"Registering\"}"});

#if defined(SIPTALK_HAS_PJSIP)
        if (!impl_->endpoint) {
            impl_->emit({
                "AccountRegistrationChanged",
                accountId,
                "",
                json_registration_payload("RegistrationFailed", "PJSIP endpoint is not ready", 0, 0),
            });
            return;
        }

        try {
            impl_->pjsipAccounts.erase(accountId);
            auto account = std::make_unique<ManagedAccount>(
                accountId,
                [this](const SipEvent& event) {
                    impl_->emit(event);
                });

            pj::AccountConfig accountConfig;
            accountConfig.idUri = sip_uri_for_user(config);
            accountConfig.regConfig.registrarUri = registrar_uri_for(config);
            accountConfig.regConfig.registerOnAdd = false;
            accountConfig.regConfig.timeoutSec = static_cast<unsigned>(config.registrationExpiresSeconds);
            accountConfig.regConfig.retryIntervalSec = 60;
            accountConfig.regConfig.firstRetryIntervalSec = 10;

            const auto authUsername = config.authUsername.empty() ? config.username : config.authUsername;
            accountConfig.sipConfig.authCreds.push_back(
                pj::AuthCredInfo("digest", "*", authUsername, 0, config.password));
            if (!config.proxy.empty()) {
                accountConfig.sipConfig.proxies.push_back(config.proxy);
            }

            account->create(accountConfig, false);
            account->setRegistration(true);
            impl_->pjsipAccounts[accountId] = std::move(account);
        } catch (const pj::Error& error) {
            impl_->emit({
                "AccountRegistrationChanged",
                accountId,
                "",
                json_registration_payload("RegistrationFailed", error.info(), 0, 0),
            });
        } catch (const std::exception& error) {
            impl_->emit({
                "AccountRegistrationChanged",
                accountId,
                "",
                json_registration_payload("RegistrationFailed", error.what(), 0, 0),
            });
        }
#endif
    });
}

void SipCore::unregisterAccount(const std::string& accountId)
{
    impl_->commandQueue.post([this, accountId] {
#if defined(SIPTALK_HAS_PJSIP)
        auto found = impl_->pjsipAccounts.find(accountId);
        if (found != impl_->pjsipAccounts.end()) {
            try {
                found->second->setRegistration(false);
            } catch (...) {
            }
            impl_->pjsipAccounts.erase(found);
        }
#endif
        impl_->emit({"AccountRegistrationChanged", accountId, "", "{\"state\":\"Offline\"}"});
    });
}

std::string SipCore::makeCall(const std::string& accountId, const std::string& destination)
{
    const auto callId = std::to_string(impl_->nextCallId.fetch_add(1));
    impl_->commandQueue.post([this, accountId, destination, callId] {
#if defined(SIPTALK_HAS_PJSIP)
        SipAccountConfig config;
        bool hasConfig = false;
        {
            std::lock_guard<std::mutex> lock(impl_->mutex);
            auto found = impl_->accounts.find(accountId);
            if (found != impl_->accounts.end()) {
                config = found->second;
                hasConfig = true;
            }
        }

        auto account = impl_->pjsipAccounts.find(accountId);
        if (!hasConfig || account == impl_->pjsipAccounts.end()) {
            impl_->emit({
                "CallStateChanged",
                accountId,
                callId,
                json_call_payload("Failed", destination, "Account is not registered", 0),
            });
            return;
        }

        const auto destinationUri = destination_uri_for(config, destination);
        impl_->emit({
            "CallStateChanged",
            accountId,
            callId,
            json_call_payload("Calling", destinationUri, "", 0),
        });

        try {
            auto call = std::make_unique<ManagedCall>(
                *account->second,
                accountId,
                callId,
                [this](const SipEvent& event) {
                    impl_->emit(event);
                });
            pj::CallOpParam callParam(true);
            call->makeCall(destinationUri, callParam);
            impl_->pjsipCalls[callId] = std::move(call);
        } catch (const pj::Error& error) {
            impl_->emit({
                "CallStateChanged",
                accountId,
                callId,
                json_call_payload("Failed", destinationUri, error.info(), 0),
            });
        } catch (const std::exception& error) {
            impl_->emit({
                "CallStateChanged",
                accountId,
                callId,
                json_call_payload("Failed", destinationUri, error.what(), 0),
            });
        }
#else
        impl_->emit({
            "CallStateChanged",
            accountId,
            callId,
            "{\"state\":\"Calling\",\"destination\":\"" + destination + "\"}",
        });
#endif
    });
    return callId;
}

void SipCore::answerCall(const std::string& callId)
{
    impl_->commandQueue.post([this, callId] {
        impl_->emit({"CallStateChanged", "", callId, "{\"state\":\"Connecting\"}"});
    });
}

void SipCore::rejectCall(const std::string& callId)
{
    impl_->commandQueue.post([this, callId] {
        impl_->emit({"CallStateChanged", "", callId, "{\"state\":\"Ended\",\"reason\":\"Rejected\"}"});
    });
}

void SipCore::hangupCall(const std::string& callId)
{
    impl_->commandQueue.post([this, callId] {
#if defined(SIPTALK_HAS_PJSIP)
        auto found = impl_->pjsipCalls.find(callId);
        if (found != impl_->pjsipCalls.end()) {
            try {
                pj::CallOpParam param;
                param.statusCode = PJSIP_SC_DECLINE;
                found->second->hangup(param);
            } catch (...) {
            }
        }
#endif
        impl_->emit({"CallStateChanged", "", callId, "{\"state\":\"Ended\",\"reason\":\"Hangup\"}"});
    });
}

void SipCore::holdCall(const std::string& callId)
{
    impl_->commandQueue.post([this, callId] {
        impl_->emit({"CallStateChanged", "", callId, "{\"state\":\"Held\"}"});
    });
}

void SipCore::resumeCall(const std::string& callId)
{
    impl_->commandQueue.post([this, callId] {
        impl_->emit({"CallStateChanged", "", callId, "{\"state\":\"InCall\"}"});
    });
}

void SipCore::sendDtmf(const std::string& callId, const std::string& digits)
{
    impl_->commandQueue.post([this, callId, digits] {
        impl_->emit({"DtmfSent", "", callId, "{\"digits\":\"" + digits + "\"}"});
    });
}

void SipCore::setMuted(const std::string& callId, bool muted)
{
    impl_->commandQueue.post([this, callId, muted] {
        impl_->emit({"MuteChanged", "", callId, muted ? "{\"muted\":true}" : "{\"muted\":false}"});
    });
}

void SipCore::setAudioRoute(const std::string& route)
{
    impl_->commandQueue.post([this, route] {
        impl_->emit({"AudioRouteChanged", "", "", "{\"route\":\"" + route + "\"}"});
    });
}

} // namespace siptalk
