## 1. Fix CI Signing Step

- [x] 1.1 Add explicit `codesign --force --sign -` step for the helper binary before app bundle signing in `.github/workflows/release.yml`
- [x] 1.2 Remove `--deep` from the app bundle signing step
- [x] 1.3 Update the verify step to use `codesign --verify --deep`

## 2. Verify

- [x] 2.1 Confirm helper `flags` no longer shows `linker-signed` in `codesign -dvvv` output
- [x] 2.2 Confirm helper `Info.plist entries=N` (N > 0) in `codesign -dvvv` output
- [x] 2.3 Confirm SMJobBless installs the helper successfully without `-67062`
