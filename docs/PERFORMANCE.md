# Performance

## Budgets

| Budget | Value | How it is checked |
|---|---|---|
| Cold start to first frame of the shell | at most 10% above the baseline below | `startup_metrics.dart`, profile build, the reference Android device |
| Effect of enabling a module on cold start | none | the same measurement with the module flag on and off |
| Frame time while scrolling Home, News, a module list | 99th percentile of build plus raster at most 16 ms | `addTimingsCallback`, profile build |
| Work at startup per module | zero network calls, zero storage reads, no controller created | a widget test with counting fakes |
| Download size per module | at most 1.0 MB added to the arm64 release | `scripts/measure_size.sh` before and after |
| Reaction to a tap | visible within 100 ms | review; optimistic update or the button's loading state |
| A wait longer than 1 s | shows a skeleton or cached content | review |

## Baseline

| Measure | Value | Device | Date | App version |
|---|---|---|---|---|
| Cold start (ms) | not measured | not measured | not measured | not measured |
| APK download size (bytes) | not measured | not measured | not measured | not measured |

The reference device is a Samsung Galaxy S23. For cold start, take the median of three runs:

```bash
./scripts/measure_startup.sh <device id>
```

The size needs Android release signing and sums the compressed entries of the arm64 APK:

```bash
./scripts/measure_size.sh
```
