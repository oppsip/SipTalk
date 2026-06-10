#include "SipCore.hpp"

#include <jni.h>

#include <memory>
#include <mutex>
#include <string>

namespace {

JavaVM* g_jvm = nullptr;
std::mutex g_core_mutex;
std::unique_ptr<siptalk::SipCore> g_core;
jobject g_native_ref = nullptr;

siptalk::SipCore& core()
{
    std::lock_guard<std::mutex> lock(g_core_mutex);
    if (!g_core) {
        g_core = std::make_unique<siptalk::SipCore>();
    }
    return *g_core;
}

std::string to_string(JNIEnv* env, jstring value)
{
    if (value == nullptr) {
        return {};
    }

    const char* chars = env->GetStringUTFChars(value, nullptr);
    std::string result(chars == nullptr ? "" : chars);
    if (chars != nullptr) {
        env->ReleaseStringUTFChars(value, chars);
    }
    return result;
}

jstring to_jstring(JNIEnv* env, const std::string& value)
{
    return env->NewStringUTF(value.c_str());
}

JNIEnv* current_env(bool& should_detach)
{
    should_detach = false;

    JNIEnv* env = nullptr;
    if (g_jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_OK) {
        return env;
    }

    if (g_jvm->AttachCurrentThread(&env, nullptr) == JNI_OK) {
        should_detach = true;
        return env;
    }

    return nullptr;
}

void emit_to_kotlin(const siptalk::SipEvent& event)
{
    if (g_jvm == nullptr) {
        return;
    }

    bool should_detach = false;
    JNIEnv* env = current_env(should_detach);
    if (env == nullptr) {
        return;
    }

    jobject native_ref = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_core_mutex);
        if (g_native_ref != nullptr) {
            native_ref = env->NewLocalRef(g_native_ref);
        }
    }
    if (native_ref == nullptr) {
        if (should_detach) {
            g_jvm->DetachCurrentThread();
        }
        return;
    }

    jclass clazz = env->GetObjectClass(native_ref);
    jmethodID method = env->GetMethodID(
        clazz,
        "emitNativeEvent",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V");
    env->DeleteLocalRef(clazz);

    if (method != nullptr) {
        jstring type = to_jstring(env, event.type);
        jstring account_id = to_jstring(env, event.accountId);
        jstring call_id = to_jstring(env, event.callId);
        jstring payload = to_jstring(env, event.payloadJson);
        env->CallVoidMethod(native_ref, method, type, account_id, call_id, payload);
        env->DeleteLocalRef(type);
        env->DeleteLocalRef(account_id);
        env->DeleteLocalRef(call_id);
        env->DeleteLocalRef(payload);
    }
    env->DeleteLocalRef(native_ref);

    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }

    if (should_detach) {
        g_jvm->DetachCurrentThread();
    }
}

} // namespace

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_initialize(JNIEnv* env, jobject thiz)
{
    if (g_jvm == nullptr) {
        env->GetJavaVM(&g_jvm);
    }
    siptalk::SipCore& sip_core = core();
    {
        std::lock_guard<std::mutex> lock(g_core_mutex);
        if (g_native_ref != nullptr) {
            env->DeleteGlobalRef(g_native_ref);
            g_native_ref = nullptr;
        }
        g_native_ref = env->NewGlobalRef(thiz);
    }

    sip_core.setEventHandler(emit_to_kotlin);
    sip_core.initialize();
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_shutdown(JNIEnv* env, jobject)
{
    std::unique_ptr<siptalk::SipCore> sip_core;
    {
        std::lock_guard<std::mutex> lock(g_core_mutex);
        sip_core = std::move(g_core);
        if (g_native_ref != nullptr) {
            env->DeleteGlobalRef(g_native_ref);
            g_native_ref = nullptr;
        }
    }
    if (sip_core) {
        sip_core->shutdown();
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_createAccount(
    JNIEnv* env,
    jobject,
    jstring id,
    jstring display_name,
    jstring domain,
    jstring username,
    jstring password,
    jstring auth_username,
    jstring proxy,
    jstring transport,
    jint registration_expires_seconds)
{
    siptalk::SipAccountConfig config;
    config.id = to_string(env, id);
    config.displayName = to_string(env, display_name);
    config.domain = to_string(env, domain);
    config.username = to_string(env, username);
    config.password = to_string(env, password);
    config.authUsername = to_string(env, auth_username);
    config.proxy = to_string(env, proxy);
    config.transport = to_string(env, transport);
    config.registrationExpiresSeconds = registration_expires_seconds;

    core().createAccount(config);
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_registerAccount(JNIEnv* env, jobject, jstring account_id)
{
    core().registerAccount(to_string(env, account_id));
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_unregisterAccount(JNIEnv* env, jobject, jstring account_id)
{
    core().unregisterAccount(to_string(env, account_id));
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_siptalk_siptalk_SipNative_makeCall(
    JNIEnv* env,
    jobject,
    jstring account_id,
    jstring destination)
{
    return to_jstring(env, core().makeCall(to_string(env, account_id), to_string(env, destination)));
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_answerCall(JNIEnv* env, jobject, jstring call_id)
{
    core().answerCall(to_string(env, call_id));
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_rejectCall(JNIEnv* env, jobject, jstring call_id)
{
    core().rejectCall(to_string(env, call_id));
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_hangupCall(JNIEnv* env, jobject, jstring call_id)
{
    core().hangupCall(to_string(env, call_id));
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_holdCall(JNIEnv* env, jobject, jstring call_id)
{
    core().holdCall(to_string(env, call_id));
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_resumeCall(JNIEnv* env, jobject, jstring call_id)
{
    core().resumeCall(to_string(env, call_id));
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_sendDtmf(JNIEnv* env, jobject, jstring call_id, jstring digits)
{
    core().sendDtmf(to_string(env, call_id), to_string(env, digits));
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_setMuted(JNIEnv* env, jobject, jstring call_id, jboolean muted)
{
    core().setMuted(to_string(env, call_id), muted == JNI_TRUE);
}

extern "C" JNIEXPORT void JNICALL
Java_com_siptalk_siptalk_SipNative_setAudioRoute(JNIEnv* env, jobject, jstring route)
{
    core().setAudioRoute(to_string(env, route));
}
