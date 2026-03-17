## 1. Repository Setup

- [x] 1.1 Create the `.github/workflows/` directory in the repository root

## 2. GitHub Actions Workflow

- [x] 2.1 Create `.github/workflows/release.yml` with trigger on `release: types: [published]`
- [x] 2.2 Configure the workflow to run on a `macos-latest` GitHub-hosted runner
- [x] 2.3 Add a build step using `xcodebuild -scheme StaticRouter -configuration Release -derivedDataPath build/DerivedData`
- [x] 2.4 Add an ad-hoc signing step: `codesign --force --deep --sign - build/DerivedData/Build/Products/Release/StaticRouter.app`
- [x] 2.5 Add a packaging step using `ditto -c -k --keepParent` to create `StaticRouteHelper-${{ github.event.release.tag_name }}.zip`
- [x] 2.6 Add an upload step to attach the `.zip` to the GitHub Release using `softprops/action-gh-release` or `actions/upload-release-asset`

## 3. README Updates (English)

- [x] 3.1 Add a "Download & Installation" section to `README.md`
- [x] 3.2 Document how to download the `.zip` from the GitHub Releases page
- [x] 3.3 Include the exact `xattr -cr /path/to/StaticRouteHelper.app` command with explanation that it removes the Gatekeeper quarantine flag
- [x] 3.4 Briefly explain why the step is needed (ad-hoc signed, not notarized, no paid Apple developer certificate)

## 4. README Updates (Chinese)

- [x] 4.1 Add a corresponding Chinese-language section to `README_CN.md`
- [x] 4.2 Document download instructions in Chinese
- [x] 4.3 Include the exact `xattr -cr` command with Chinese explanation
- [x] 4.4 Explain in Chinese why the step is needed (未经公证，无付费开发者证书)

## 5. Verification

- [ ] 5.1 Push a test tag / draft release and verify the workflow triggers and completes successfully
- [ ] 5.2 Verify the `.zip` asset appears on the GitHub Release page
- [ ] 5.3 Download the `.zip`, run `xattr -cr` on the `.app`, and confirm the app launches on macOS
