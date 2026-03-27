
A day ago a post hit my feed and made me laugh.

Someone had built a nice retro split-flap component for the web, priced it at $199, and then watched in real time as another person vibe-coded a clone with Claude in about 15 minutes and published it for free. Classic 2026 moment. The internet moves fast, lol.

I didn't need a split-flap board for anything.

I just got curious about how hard it would actually be to build a *correct* one — not just something that looks right in a screenshot, but something that behaves like the real machine. Those old Solari airport boards have a specific mechanic people often skip: each character position is a physical drum cycling through a fixed sequence. It doesn't jump to the target letter — it rolls forward through A, B, C, D… until it lands there. If the target is behind where you are, you go all the way around. Sometimes you watch 20+ characters roll past before it snaps into place.

That unoptimized, slightly wasteful physical behavior is exactly what makes them satisfying to watch.

So, I went down the rabbit hole. :)

## Attempt 1: One widget per flap

My first version was the obvious Flutter one: every flap is a widget — Transform, Opacity, AnimatedBuilder. Ten rows, 35 characters wide, so roughly 350 widgets all animating 3D transforms at the same time.

The board moved like it was underwater. FPS dropped into the teens, the browser compositor was choking, and my laptop fan sounded like a hair dryer. It looked fine in a still screenshot. In motion it was unwatchable.

## Attempt 2: One CustomPainter per row

I threw away the widget tree and moved to a single CustomPainter per row. Widget count: from 350 to about 10. That alone gave the renderer room to breathe.

This is also where I got the mechanical behavior right. Each character position holds an index into a fixed alphabet. When the text changes, the position increments that index one step per animation tick until it hits the target — no shortcuts. You see the characters roll past, same as the physical drum.

I added Matrix4 perspective, a visible hinge gap down the center (that thin black line is load-bearing for the effect), and gradient shading to make the flaps feel like painted metal. Staggered start delays between rows — about 150 ms — so the board looks alive rather than perfectly synchronized.

Better. But something was still eating CPU in the background.

## Attempt 3: Caching the text layout

The profiler pointed at TextPainter.layout(). On Flutter Web, recalculating text layout for every character on every animated frame — at 60 FPS, across hundreds of positions — adds up fast. Not something you'd catch in a small test, but at board scale it was significant.

Fix: pre-render a TextPainter for every character at startup, cache them, reuse during animation. No layout on hot frames.

Smoother. But I could still feel us fighting the vector drawing pipeline harder than necessary.

## Attempt 4: Bitmap textures

I stopped using vector drawing for the characters entirely.

At startup, the app renders every character in the alphabet — top half and bottom half separately, the two physical halves of a split flap — onto a single ui.Image texture atlas. One image in GPU memory, shared by every row. From that point, rendering a character is just canvas.drawImageRect: a pixel copy the GPU does for almost nothing.

The mechanical behavior is unchanged. The hinge split, the forward-only drum cycling, the 3D rotation — all still there. Just no more vector work per frame.

One gotcha: generating the sprite sheet synchronously on startup crashes the CanvasKit WebGL context — too much work before the first frame paints. Had to make it async and render a placeholder while waiting.

After that: solid 60 FPS regardless of how many rows are animating. The work is paid once at startup; the animation itself costs almost nothing.
Then I made it sound right

Once the visuals were stable I wanted the audio to match. A real Solari board in a busy airport is loud — dozens of plastic flaps snapping into place, layering into a continuous mechanical rattle when a wave of departures updates at once.

The straightforward approach (play a click on each animation step from a single AudioPlayer) immediately ran into two problems.

Web autoplay policy. Browsers block all audio until an actual user gesture fires a play() call — and it has to be synchronous within that event handler. Any await before the play() breaks the browser's gesture detection and it blocks the sound silently. This one burned a few hours.

AudioPlayer  is monophonic. When 35 positions are flipping simultaneously, each play() call interrupts the previous one before it emits any sound. You end up with almost no audio at all — just a continuous stream of cancellations.

Solution: a pool of four pre-loaded AudioPlayer instances rotating round-robin. Up to four clicks overlap at once, which produces something close to the actual texture of a busy board.

I also added a looping ambient layer — a continuous mechanical hum — whose volume and speed scale with how many positions are actively flipping.

density is just activeFlips / totalCapacity, a 0–1 value that describes how busy the board is at any moment.

> loopVolume    = density^0.4 × 0.75 + 0.08

> playbackSpeed = 0.96 + density × 0.28

The ^0.4 exponent on volume is the key part: raising a number below 1 to a fractional power makes it grow quickly at first then level off. In practice it means the hum becomes audible with just a handful of flips, then barely increases as the board fills up — which is closer to how we actually perceive loudness than a straight linear scale would be. The + 0.08 is a minimum floor so there's always a faint hum the moment any row starts moving.

The speed formula: 0.96 is the base playback rate at idle — just slightly under 1× so the loop sounds like a motor ticking over, not running at full speed. 0.28 is the maximum increase, meaning at full density the loop plays at 0.96 + 0.28 = 1.24×, about 24% faster than baseline — simulating a motor running under heavier load.

Individual click volume scales down as density increases, so the full-load mix doesn't clip even with multiple clicks firing per second.

There was one more subtle bug: the clock in the header is also a SplitFlapRow — it updates every minute. Without explicitly excluding it, the activity tracker thought the board was always running, so the ambient loop never stopped. Added a silent: true flag for rows that should animate without affecting the audio state.

When all rows actually finish, the audio stops immediately — setVolume(0) and stop(). No lingering fade. The board goes quiet the way a machine does when it stops moving.

## The final result

→ **[Live demo]()**

Responsive across mobile, tablet, and desktop. Single shared sprite sheet in GPU memory. Audio that actually scales with what the board is doing.

Stack: CustomPainter, ui.Image, Matrix4, just_audio. Nothing external beyond the audio package.

Started as a quick Thursday rabbit hole, ended a few iterations later with something that actually holds up. A prototype can look right on the first try — the gap shows up when you try to scale it.

What have you been building this week?
