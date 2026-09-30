{{flutter_js}}
{{flutter_build_config}}

// One-time versioning bypasses stale CDN entries created before Flutter Web
// entry points were configured for revalidation.
for (const build of _flutter.buildConfig.builds) {
  build.mainJsPath = `${build.mainJsPath}?v=20260930`;
}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
