# ---------------------------------------------------------------------------
# check blocks (Terraform 1.5+): post-apply assertions on the REAL deployed
# infrastructure. They run on plan and apply, and report FAILURES as warnings -
# they never block the workflow. The scoped data source is re-read every run, so
# out-of-band drift is caught on the next plan.
# ---------------------------------------------------------------------------
check "website_health" {
  data "http" "home" {
    url = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
  }

  assert {
    condition     = data.http.home.status_code == 200
    error_message = "Website returned HTTP ${data.http.home.status_code}, expected 200 (is the site up?)."
  }

  assert {
    condition     = strcontains(data.http.home.response_body, local.health_marker)
    error_message = "Website body is missing the expected marker - content drift or a broken deploy."
  }
}
