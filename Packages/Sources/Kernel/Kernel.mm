#import "C++/Kernel.hpp"

// This must be done in a source file -- include files cannot see the Swift bridging file.

@import ParameterAddress;

void Kernel::setParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept {
  os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "setRampedParameterValue - %llul %f %d", address, value, duration);
  switch (address) {
    case ParameterAddressCutoff: cutoff_.set(value, duration); break;
    case ParameterAddressResonance: resonance_.set(value, duration); break;
  }
}

AUValue Kernel::getParameterValue(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressCutoff: return cutoff_.get();
    case ParameterAddressResonance: return resonance_.get();
  }
  return 0.0;
}
