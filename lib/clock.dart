/// The Rubik's Clock.
///
/// The odd one out: no search, and no table either. Fourteen dials of twelve
/// positions, fourteen moves that each turn exactly one of them, so the puzzle
/// is the group `(Z12)^14` and its notation is its state.
///
/// ```dart
/// final scramble = randomClockScramble();
/// // UR2- DR5- DL0+ UL1+ U2+ R0+ D3+ L5- ALL5- y2 U4- R3- D1+ L2- ALL3+
///
/// print(scramble.movesToSolve);       // however many dials are off zero
/// print(scramble.inverse);            // the moves that put it back
/// ```
library;

export "clock/clock.dart" show ClockState, randomClockScramble;
export "clock/layout.dart" show ClockLayout, clockLayout;
export "cube/layout.dart" show Point;
export "clock/dials.dart"
    show
        ClockDialReading,
        ClockDials,
        clockCorners,
        clockMoveEffect,
        dialBlock,
        mirroredDial,
        nClockDials;
