#import "C++/Kernel.hpp"

// This must be done in a source file -- include files cannot see the Swift bridging file.

@import ParameterAddress;

void Kernel::setParameterValue(AUParameterAddress address, AUValue value) {
  os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "setParameterValue - %llul %f", address, value);
  switch (address) {
    case ParameterAddressCutoff: cutoff_.set(value, 0); break;
    case ParameterAddressResonance: resonance_.set(value, 0); break;
  }
}

void Kernel::setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) {
  os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "setRampedParameterValue - %llul %f %d", address, value, duration);
  switch (address) {
    case ParameterAddressCutoff: cutoff_.set(value, duration); break;
    case ParameterAddressResonance: resonance_.set(value, duration); break;
  }
}

AUValue Kernel::getParameterValue(AUParameterAddress address) const {
  switch (address) {
    case ParameterAddressCutoff: return cutoff_.get();
    case ParameterAddressResonance: return resonance_.get();
  }
  return 0.0;
}
