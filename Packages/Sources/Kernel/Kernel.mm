#import "C++/Kernel.hpp"

// This must be done in a source file -- include files cannot see the Swift bridging file.

@import ParameterAddress;

bool Kernel::doSetImmediateParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept {
  switch (address) {
    case ParameterAddressCutoff: cutoff_.setImmediate(value, duration); return true;
    case ParameterAddressResonance: resonance_.setImmediate(value, duration); return true;
  }
  return false;
}

bool Kernel::doSetPendingParameterValue(AUParameterAddress address, AUValue value) noexcept {
  switch (address) {
    case ParameterAddressCutoff: cutoff_.setPending(value); return true;
    case ParameterAddressResonance: resonance_.setPending(value); return true;
  }
  return false;
}

AUValue Kernel::doGetImmediateParameterValue(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressCutoff: return cutoff_.getImmediate();
    case ParameterAddressResonance: return resonance_.getImmediate();
  }
  return 0.0;
}

AUValue Kernel::doGetPendingParameterValue(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressCutoff: return cutoff_.getPending();
    case ParameterAddressResonance: return resonance_.getPending();
  }
  return 0.0;
}
