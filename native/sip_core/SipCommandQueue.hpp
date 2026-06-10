#pragma once

#include <condition_variable>
#include <functional>
#include <mutex>
#include <queue>
#include <thread>

namespace siptalk {

class SipCommandQueue {
public:
    SipCommandQueue();
    ~SipCommandQueue();

    SipCommandQueue(const SipCommandQueue&) = delete;
    SipCommandQueue& operator=(const SipCommandQueue&) = delete;

    void start();
    void stop();
    void drainAndStop();
    void post(std::function<void()> command);

private:
    void run();

    std::mutex mutex_;
    std::condition_variable condition_;
    std::queue<std::function<void()>> commands_;
    std::thread worker_;
    bool running_ = false;
};

} // namespace siptalk
