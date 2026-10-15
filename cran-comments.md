## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Test environments

* local Windows 11, R 4.6.1
* GitHub Actions: ubuntu-latest (R release and R-devel), windows-latest
  (R release), macos-latest (R release)

## Notes for the reviewer

* The package is a client for a self-hosted trading application. Every
  method needs a running 'OpenAlgo' server and a personal API key, so the
  examples are wrapped in \dontrun{}.
* The tests run against local mock servers only ('webfakes' for HTTP and an
  in-process 'httpuv' server for the WebSocket feed). Tests that talk to a
  real server are skipped on CRAN and whenever the OPENALGO_API_KEY
  environment variable is not set. Timing-sensitive tests are skipped on
  CRAN.
