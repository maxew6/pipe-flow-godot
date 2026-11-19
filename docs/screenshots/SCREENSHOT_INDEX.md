# Pipe Flow v0.5.0 screenshot evidence

All 22 images were captured from the real Godot scenes through Xvfb at their labelled native dimensions. Each resolution folder has the same eleven states: `01-main-menu.png`, `02-settings.png`, `03-level-select.png`, `04-gameplay-idle.png`, `05-pause.png`, `06-water-start.png`, `07-water-mid-stream.png`, `08-water-near-end.png`, `09-level-complete.png`, `10-sealed-network-leak-immediate.png`, and `11-sealed-network-leak-message.png`.

The level-select capture uses an isolated fresh-save directory. In the final two leak captures, the route still reaches the tap but an open tee branch fails the sealed-network rule. The real game displays the red leak marker and the message that every open pipe end must meet a pipe or an end cap. Successful completion captures show the tank drained and the success UI. The water timeline capture set includes start, mid-stream, near-end, and completion states.
