# DoomsBlocker — Antigravity Agent Configuration

This workspace operates under **Spec-Driven Development (SDD)**.

## Mandatory Agent Workflow
1. **Always read `SPECIFICATIONS.md` and `AGENTS.md`** before planning or applying code changes.
2. **Never break existing invariants**:
   - Status bar/System UI (`com.android.systemui`) package filtering.
   - Long-form educational YouTube playback exemption.
   - Study Zone state machine: check-in before check-out, no PIN bypass, social media and games blocked.
   - Smooth 5-second countdown lock overlay with 1.5s back-press immunity guard.
   - Viewfinder transparent cutout using `CustomPainter` with `PathOperation.difference`.
   - Zero hardcoding: all times and limits must be dynamic via `SharedPreferences`.
3. **Always run the Automated Spec Driver** after modifications:
   ```bash
   flutter test test/spec_driver_test.dart
   ```
4. **Update tests and specifications** whenever introducing new behaviors.
