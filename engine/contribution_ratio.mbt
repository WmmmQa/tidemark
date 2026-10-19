///|
/// Contribution margin as truncated basis points (10,000 bp = 100%).
/// Returns None when the operating assumptions are invalid.
pub fn contribution_ratio_bps(case : @domain.CvpCase) -> Int64? {
  if case.issues().length() > 0 {
    return None
  }
  Some(case.contribution_fen() * 10_000L / case.selling_price_fen)
}
