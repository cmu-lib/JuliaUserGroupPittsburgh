<!--
Global settings for the site. Variables defined here are available on every page.
-->
@def website_title = "Julia Language User Group — Pittsburgh"
@def website_descr = "Monthly meetings of Julia users at Carnegie Mellon University"
@def website_url   = "https://cmu-lib.github.io/JuliaUserGroupPittsburgh/"
@def author        = "Julia Language User Group — Pittsburgh"

<!-- Sub-path used when the site is served from GitHub Pages; see optimize() in the deploy workflow. -->
@def prepath = "JuliaUserGroupPittsburgh"

@def generate_rss = false

<!-- Meeting defaults; a meeting page can override them. -->
@def meeting_time = "5:00 PM"
@def meeting_room = "Wean Hall (WEH) 2327"
@def meeting_hours = 2

<!-- Set to true on the home page to render the full poster layout. -->
@def is_home = false
