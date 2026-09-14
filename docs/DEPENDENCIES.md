# Dependency inventory

LocalFlow has no third-party runtime packages. Its executable links Apple's
AppKit, Foundation, AVFoundation, Speech, CoreGraphics, Carbon/HIServices, and the
Swift standard libraries supplied with macOS. Apple speech assets are a
proprietary OS dependency and must be provisioned before offline operation.

Application, installer, and test source is in this MIT-licensed repository.
The test driver is a separate executable and is excluded from distribution.
The app does not bundle OpenCode; it is a separately installed test destination.

Build/test requirements: macOS 14+, Swift 6+, and a compatible macOS SDK.
Hosted checks select Xcode 16.2, 16.4, and 26.3. Python 3 is used for development
verification scripts; it is not required to install or run the app. Employees
need only standard macOS tools for the offline installer.

CI-only tools: GitHub Actions checkout and CodeQL (pinned to immutable commits in
the workflows), Gitleaks 8.30.1 (release archive verified with SHA-256), and
ShellCheck from the hosted runner image. Dependabot checks action updates.
The host OS and scanner databases are maintained upstream; their exact versions
are visible in each CI run. No scan is a guarantee of zero vulnerabilities.
