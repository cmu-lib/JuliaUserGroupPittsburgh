# Helper functions for the site. Functions named `hfun_*` can be called from
# layouts and pages as `{{name ...}}`; functions named `lx_*` define LaTeX-like commands.

using Dates

hfun_current_year() = string(year(today()))

# ------------------------------------------------------------------
# Meetings
#
# Each meeting is a page meetings/YYYY-MM-DD.md defining `meeting_date`,
# `title` and optionally `speaker`, `meeting_time`, `meeting_room` and
# `status` ("scheduled", "postponed" or "cancelled"). Upcoming and past
# are relative to the build date, so the site is rebuilt daily.
# ------------------------------------------------------------------

const MEETINGS_DIR = "meetings"

_fmt_date(d) = Dates.format(d, "E, U d, yyyy")

# All meeting pages as named tuples, sorted by date (oldest first).
function _meetings()
    meetings = []
    for file in readdir(MEETINGS_DIR)
        (endswith(file, ".md") && file != "index.md") || continue
        rpath = joinpath(MEETINGS_DIR, splitext(file)[1])
        date = pagevar(rpath, :meeting_date)
        date === nothing && continue
        push!(meetings, (
            url     = "/$rpath/",
            date    = date,
            title   = something(pagevar(rpath, :title), "Meeting"),
            speaker = something(pagevar(rpath, :speaker), ""),
            time    = something(pagevar(rpath, :meeting_time), globvar(:meeting_time)),
            room    = something(pagevar(rpath, :meeting_room), globvar(:meeting_room)),
            status  = something(pagevar(rpath, :status), "scheduled"),
        ))
    end
    return sort(meetings, by = m -> m.date)
end

_status_badge(status) = status == "scheduled" ? "" :
    """ <span class="status status-$status">$(titlecase(status))</span>"""

function _meeting_item(m)
    speaker = isempty(m.speaker) ? "" : """<span class="meeting-speaker">$(m.speaker)</span>"""
    return """
    <li class="meeting-item">
      <time datetime="$(m.date)">$(_fmt_date(m.date))</time>$(_status_badge(m.status))
      <a href="$(m.url)">$(m.title)</a>
      $speaker
    </li>
    """
end

# Lists of upcoming and past meetings, for meetings/index.md.
function hfun_meetings_list()
    meetings = _meetings()
    upcoming = filter(m -> m.date >= today(), meetings)
    past = reverse(filter(m -> m.date < today(), meetings))
    io = IOBuffer()
    println(io, "<h2>Upcoming</h2>")
    if isempty(upcoming)
        println(io, "<p>The next meeting will be announced soon.</p>")
    else
        println(io, "<ul class=\"meeting-list\">", join(_meeting_item.(upcoming)), "</ul>")
    end
    if !isempty(past)
        println(io, "<h2>Past meetings</h2>")
        println(io, "<ul class=\"meeting-list\">", join(_meeting_item.(past)), "</ul>")
    end
    return String(take!(io))
end

_next_meeting() = (upcoming = filter(m -> m.date >= today() && m.status != "cancelled", _meetings());
                   isempty(upcoming) ? nothing : first(upcoming))

# Card with the next meeting, for the home page.
function hfun_next_meeting()
    m = _next_meeting()
    m === nothing && return ""
    _write_calendar(NEXT_ICS, [m])
    speaker = isempty(m.speaker) ? "" : " — $(m.speaker)"
    return """
    <div class="next-meeting">
      <span class="next-meeting-label">Next meeting$(_status_badge(m.status))</span>
      <a href="$(m.url)">$(m.title)</a>$speaker
      <span class="next-meeting-when"><time datetime="$(m.date)">$(_fmt_date(m.date))</time> · $(m.time) · $(m.room)</span>
      <span class="next-meeting-links">
        <a href="/$NEXT_ICS" download>Add to calendar (.ics)</a>
        <a href="$(_google_calendar_url(m))" rel="noopener">Google Calendar</a>
        <a href="/$MEETINGS_DIR/">All meetings →</a>
      </span>
    </div>
    """
end

# ------------------------------------------------------------------
# Calendar (iCalendar, RFC 5545)
#
# calendar.ics holds every meeting and can be subscribed to;
# next-meeting.ics holds only the next one. Both are written into the
# built site while the pages that link to them are rendered.
# ------------------------------------------------------------------

const FEED_ICS = "calendar.ics"
const NEXT_ICS = "next-meeting.ics"
const TZID = "America/New_York"

# US Eastern time with the post-2007 daylight saving rules.
const VTIMEZONE = """
BEGIN:VTIMEZONE
TZID:America/New_York
BEGIN:DAYLIGHT
TZOFFSETFROM:-0500
TZOFFSETTO:-0400
TZNAME:EDT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:-0400
TZOFFSETTO:-0500
TZNAME:EST
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
END:STANDARD
END:VTIMEZONE"""

_ics_escape(s) = replace(s, "\\" => "\\\\", ";" => "\\;", "," => "\\,", "\n" => "\\n")

# Lines longer than 75 octets are folded onto continuation lines starting with a space.
function _ics_fold(line)
    out, chunk = String[], ""
    for c in line
        if ncodeunits(chunk) + ncodeunits(string(c)) > (isempty(out) ? 75 : 74)
            push!(out, chunk)
            chunk = ""
        end
        chunk *= c
    end
    push!(out, chunk)
    return join(out, "\r\n ")
end

_ics_datetime(dt) = Dates.format(dt, "yyyymmdd\\THHMMSS")

function _meeting_start_end(m)
    start = DateTime(m.date, Time(m.time, dateformat"I:MM p"))
    return start, start + Minute(round(Int, 60 * globvar(:meeting_hours)))
end

_absolute_url(path) = rstrip(globvar(:website_url), '/') * path

function _vevent(m, stamp)
    start, stop = _meeting_start_end(m)
    status = Dict("postponed" => "TENTATIVE", "cancelled" => "CANCELLED")
    description = (isempty(m.speaker) ? "" : "Speaker: $(m.speaker)\n") * _absolute_url(m.url)
    lines = [
        "BEGIN:VEVENT",
        "UID:$(m.date)@$(replace(globvar(:website_url), r"^https?://" => "", r"/$" => ""))",
        "DTSTAMP:$stamp",
        "DTSTART;TZID=$TZID:$(_ics_datetime(start))",
        "DTEND;TZID=$TZID:$(_ics_datetime(stop))",
        "SUMMARY:" * _ics_escape("Julia User Group: $(m.title)"),
        "LOCATION:" * _ics_escape("$(m.room), Carnegie Mellon University, Pittsburgh, PA"),
        "DESCRIPTION:" * _ics_escape(description),
        "URL:" * _absolute_url(m.url),
        "STATUS:" * get(status, m.status, "CONFIRMED"),
        "END:VEVENT",
    ]
    return join(_ics_fold.(lines), "\r\n")
end

function _write_calendar(file, meetings)
    stamp = Dates.format(now(Dates.UTC), "yyyymmdd\\THHMMSS\\Z")
    header = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Julia Language User Group Pittsburgh//Website//EN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        _ics_fold("X-WR-CALNAME:" * _ics_escape(globvar(:website_title))),
        "X-WR-TIMEZONE:$TZID",
    ]
    parts = vcat(join(header, "\r\n"), replace(VTIMEZONE, "\n" => "\r\n"),
                 [_vevent(m, stamp) for m in meetings], "END:VCALENDAR")
    mkpath(Franklin.path(:site))
    write(joinpath(Franklin.path(:site), file), join(parts, "\r\n") * "\r\n")
end

_url_encode(s) = join(c in ('-', '_', '.', '~') || (isascii(c) && isletter(c)) || isdigit(c) ?
                      string(c) : join("%" .* uppercase.(string.(codeunits(string(c)), base=16, pad=2)))
                      for c in s)

function _google_calendar_url(m)
    start, stop = _meeting_start_end(m)
    params = [
        "action" => "TEMPLATE",
        "text" => "Julia User Group: $(m.title)",
        "dates" => "$(_ics_datetime(start))/$(_ics_datetime(stop))",
        "ctz" => TZID,
        "location" => "$(m.room), Carnegie Mellon University",
        "details" => _absolute_url(m.url),
    ]
    return "https://calendar.google.com/calendar/render?" *
           join(("$k=$(_url_encode(v))" for (k, v) in params), "&amp;")
end

# Writes the full feed and returns subscription links, for meetings/index.md.
function hfun_calendar_feed()
    _write_calendar(FEED_ICS, filter(m -> m.status != "cancelled" || m.date >= today(), _meetings()))
    feed = _absolute_url("/$FEED_ICS")
    webcal = replace(feed, r"^https?://" => "webcal://")
    return """
    <p class="calendar-feed">
      <strong>Subscribe to the calendar:</strong>
      <a href="$webcal">Apple / Outlook</a> ·
      <a href="https://calendar.google.com/calendar/r?cid=$(_url_encode(webcal))" rel="noopener">Google Calendar</a> ·
      <a href="/$FEED_ICS">calendar.ics</a>
    </p>
    """
end

# Date, time, place and status block at the top of a meeting page.
function hfun_meeting_info()
    date = locvar(:meeting_date)
    date === nothing && return ""
    time = something(locvar(:meeting_time), globvar(:meeting_time))
    room = something(locvar(:meeting_room), globvar(:meeting_room))
    speaker = something(locvar(:speaker), "")
    status = something(locvar(:status), "scheduled")
    speaker_line = isempty(speaker) ? "" : "<p><strong>Speaker:</strong> $speaker</p>"
    return """
    <div class="meeting-info">
      <p><strong><time datetime="$date">$(_fmt_date(date))</time></strong> · $time$(_status_badge(status))</p>
      <p>$room, Carnegie Mellon University</p>
      $speaker_line
    </div>
    """
end

# ------------------------------------------------------------------
# Bridge decorations
#
# Abstract Pittsburgh bridges drawn as SVG line art. A suspension cable
# carrying a uniform deck hangs as a parabola, and the arches are
# parabolic too, so every curve below is y = a(x - x0)^2 + y0.
# ------------------------------------------------------------------

# SVG path through the points (x, y) for x in xs.
function _polyline(f, xs)
    pts = ["$(round(x, digits=1)),$(round(f(x), digits=1))" for x in xs]
    return "M" * join(pts, " L")
end

_line(x1, y1, x2, y2) = "M$(round(x1, digits=1)),$(round(y1, digits=1)) L$(round(x2, digits=1)),$(round(y2, digits=1))"

# Parabola through (x1, ytop) and (x2, ytop) with its lowest (or highest) point ymid.
_parabola(x1, x2, ytop, ymid) = x -> ymid + (ytop - ymid) * ((x - (x1 + x2) / 2) / ((x2 - x1) / 2))^2

# Suspension bridge: two towers, a parabolic main span, side spans down to
# the deck, and vertical hangers from the cables to the deck.
function _suspension(x1, t1, t2, x2; deck, top, sag, step=16)
    cable = _parabola(t1, t2, top, sag)
    # Side spans: straight from tower top to the deck, plus a small sag.
    side(s) = top + (deck - top) * s + 0.12 * (deck - top) * 4s * (1 - s)
    left  = x -> side((t1 - x) / (t1 - x1))
    right = x -> side((x - t2) / (x2 - t2))
    paths = [_polyline(cable, range(t1, t2, length=60)),
             _line(t1, top - 10, t1, deck + 8), _line(t2, top - 10, t2, deck + 8)]
    hangers = [_line(x, cable(x), x, deck) for x in (t1 + step):step:(t2 - step / 2)]
    # Side spans, when the deck extends past the towers.
    if x1 < t1
        push!(paths, _polyline(left, range(x1, t1, length=24)))
        append!(hangers, [_line(x, left(x), x, deck) for x in (x1 + step):step:(t1 - step / 2)])
    end
    if t2 < x2
        push!(paths, _polyline(right, range(t2, x2, length=24)))
        append!(hangers, [_line(x, right(x), x, deck) for x in (t2 + step):step:(x2 - step / 2)])
    end
    return (main=paths, thin=hangers)
end

# Bowstring arch: two nested parabolic arches with the deck hung below them.
function _arch(x1, x2; deck, rise, step=18)
    outer = _parabola(x1, x2, deck, deck - rise)
    inner = _parabola(x1 + 10, x2 - 10, deck, deck - rise + 12)
    paths = [_polyline(outer, range(x1, x2, length=60)),
             _polyline(inner, range(x1 + 10, x2 - 10, length=60))]
    hangers = [_line(x, inner(x), x, deck) for x in (x1 + 10 + step):step:(x2 - 10 - step / 2)]
    return (main=paths, thin=hangers)
end

function _svg(width, height, main, thin; class, aspect)
    d_main = join(main, " ")
    d_thin = join(thin, " ")
    return """
    <svg class="$class" viewBox="0 0 $width $height" preserveAspectRatio="$aspect" aria-hidden="true" focusable="false">
      <path class="bridge-thin" d="$d_thin"/>
      <path class="bridge-main" d="$d_main"/>
    </svg>
    """
end

# Thin band of suspension cables along the top of every page.
function hfun_bridges_top()
    width, height = 1600, 60
    deck = 46
    main, thin = String[], String[]
    for t in 0:200:(width - 200)
        b = _suspension(t, t, t + 200, t + 200; deck=deck, top=10, sag=36, step=14)
        append!(main, b.main)
        append!(thin, b.thin)
    end
    push!(main, _line(0, deck, width, deck))
    return _svg(width, height, main, thin; class="bridges bridges-top", aspect="xMidYMin slice")
end

# Footer band: suspension, arch and suspension bridges over the three
# rivers meeting at the Point (Allegheny + Monongahela = Ohio).
function hfun_bridges_bottom()
    width, height = 1600, 220
    deck = 150
    main, thin = String[], String[]
    for b in (_suspension(60, 160, 460, 560; deck=deck, top=40, sag=128),
              _arch(650, 990; deck=deck, rise=95),
              _suspension(1080, 1180, 1440, 1540; deck=deck, top=60, sag=132))
        append!(main, b.main)
        append!(thin, b.thin)
    end
    push!(main, _line(0, deck, width, deck), _line(0, deck + 6, width, deck + 6))
    # Rivers: two lines converge at the Point and continue as one.
    point = (1150, 192)
    push!(thin, _line(0, 172, point...), _line(0, 212, point...), _line(point..., width, point[2]))
    return _svg(width, height, main, thin; class="bridges bridges-bottom", aspect="xMidYMax slice")
end
