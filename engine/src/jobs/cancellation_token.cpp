#include "cancellation_token.hpp"

namespace convertor {

CancellationToken::CancellationToken() = default;
void CancellationToken::cancel() { cancelled_.store(true); }
bool CancellationToken::is_cancelled() const { return cancelled_.load(); }
void CancellationToken::reset() { cancelled_.store(false); }

} // namespace convertor
