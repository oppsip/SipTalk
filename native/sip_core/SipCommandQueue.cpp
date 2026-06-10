#include "SipCommandQueue.hpp"

namespace siptalk {

SipCommandQueue::SipCommandQueue() = default;

SipCommandQueue::~SipCommandQueue()
{
    stop();
}

void SipCommandQueue::start()
{
    std::lock_guard<std::mutex> lock(mutex_);
    if (running_) {
        return;
    }

    running_ = true;
    worker_ = std::thread([this] { run(); });
}

void SipCommandQueue::stop()
{
    {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!running_) {
            return;
        }
        running_ = false;
    }

    condition_.notify_all();
    if (worker_.joinable()) {
        worker_.join();
    }
}

void SipCommandQueue::drainAndStop()
{
    while (true) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (commands_.empty()) {
                break;
            }
        }
        std::this_thread::yield();
    }

    stop();
}

void SipCommandQueue::post(std::function<void()> command)
{
    {
        std::lock_guard<std::mutex> lock(mutex_);
        commands_.push(std::move(command));
    }

    condition_.notify_one();
}

void SipCommandQueue::run()
{
    while (true) {
        std::function<void()> command;

        {
            std::unique_lock<std::mutex> lock(mutex_);
            condition_.wait(lock, [this] {
                return !running_ || !commands_.empty();
            });

            if (!running_ && commands_.empty()) {
                return;
            }

            command = std::move(commands_.front());
            commands_.pop();
        }

        command();
    }
}

} // namespace siptalk
